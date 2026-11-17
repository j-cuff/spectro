# VDURA PanFS CSI Driver

This pack deploys the [VDURA PanFS CSI driver](https://github.com/panasasinc/panfs-container-storage-interface-oss) (`com.vdura.csi.panfs`). Pods can then use PanFS volumes as ReadWriteMany or ReadWriteOnce persistent volumes, with dynamic provisioning, online expansion, quotas, and optional end-to-end encryption.

The pack installs three Helm charts into the `csi-panfs` namespace:

| Chart | What it creates |
|---|---|
| `csi-panfs-registry-secret` | Image pull secret for VDURA's private PanFS DFC and KMM images |
| `csi-panfs` (upstream 1.2.5) | CSI controller Deployment, node plugin DaemonSet, `CSIDriver`, and a KMM `Module` that loads the `panfs` kernel module on client nodes |
| `csi-panfs-storageclass` (upstream 1.2.5) | Realm credentials Secret and the `csi-panfs-storage-class` StorageClass |

## Prerequisites

- Kubernetes 1.30.1 or later.
- Access to VDURA's private registry, with `panfs-dfc` and `panfs-kmm` images built for the exact kernel your client nodes run. Get the registry details, credentials, and DFC release version from VDURA.
- A DFC and PanFS release that VDURA supports with driver 1.2.5. Driver 1.2.5 differs from 1.2.3 in two ways that depend on that release:
  - With `kmm.encryptionSupport: true`, KMM loads the encryption module as `libwolfssl` (1.2.3 used `wolfssl`), so the `panfs-kmm` image must ship it under that name.
  - The StorageClass parameter for the storage set is `panfs.csi.vdura.com/storageset`. The driver ignores the 1.2.3 parameter, `panfs.csi.vdura.com/bladeset`, so don't copy StorageClass values from a 1.2.3 deployment.
- Network access from every client node to the PanFS realm on the ports listed in the PanFS documentation.
- PanFS realm credentials: a username plus either a password or an SSH private key.
- The **cert-manager** pack and the **Kernel Module Management (KMM)** pack, placed below this pack in the cluster profile. You can skip both only if every client node already has the `panfs` kernel module loaded and you set `kmm.enabled: false`.
- SELinux: `seLinux: true` (the default) mounts `/sys/fs/selinux` and `/etc/selinux` from the host. On nodes without SELinux, such as Ubuntu, set `seLinux: false` or the node plugin will not start.

## Parameters

Every required value is marked `REQUIRED` in the pack values.

| Parameter | Description | Required |
|---|---|---|
| `charts.csi-panfs-registry-secret.registry.server` | Registry host for the DFC/KMM images, for example `registry.example.com` | Yes, unless `create: false` |
| `charts.csi-panfs-registry-secret.registry.username` / `.password` | Registry credentials | Yes, unless `create: false` |
| `charts.csi-panfs.dfc.privateRegistry` | Registry and path that hold `panfs-dfc` and `panfs-kmm`, for example `registry.example.com/vdura` | Yes |
| `charts.csi-panfs.dfc.version` | DFC release version (image tag) | Yes |
| `charts.csi-panfs.kmm.kernelMappings[].containerImage` | Kernel module image. Replace `<REGISTRY>` and `<DFC_VERSION>` with the two values above and leave `${KERNEL_FULL_VERSION}` as is | Yes, when `kmm.enabled` |
| `charts.csi-panfs.kmm.selector` / `nodeServer.selector` | Nodes that act as PanFS clients. Default `panfs.csi.vdura.com/client: "true"` | No |
| `charts.csi-panfs.seLinux` | SELinux integration. Default `true` | No |
| `charts.csi-panfs.kmm.enabled` | Load the kernel module with KMM. Default `true` | No |
| `charts.csi-panfs-storageclass.realm.address` | PanFS realm hostname or IP | Yes |
| `charts.csi-panfs-storageclass.realm.username` | Realm user | Yes |
| `charts.csi-panfs-storageclass.realm.password` or `.privateKey` | Realm password, or SSH private key (plus `privateKeyPassphrase`) | One of them |
| `charts.csi-panfs-storageclass.setAsDefaultStorageClass` | Make PanFS the default StorageClass. Default `false` | No |
| `charts.csi-panfs-storageclass.parameters` | PanFS volume create parameters (layout, storage set, permissions, encryption) | No |

## Usage

1. **Build the profile.** Add the add-on layers in this order, bottom to top: cert-manager, Kernel Module Management (KMM), then VDURA PanFS CSI Driver.

2. **Label the client nodes.** In the cluster's node pool configuration, add the node label `panfs.csi.vdura.com/client=true` to every pool that should mount PanFS. To label an existing cluster:

   ```bash
   kubectl label node <node-name> panfs.csi.vdura.com/client=true
   ```

3. **Store secrets as profile variables.** Define sensitive profile variables for the registry password and realm password or key, then reference them in the pack values:

   ```yaml
   realm:
     password: "{{ .spectro.var.vdura_realm_password }}"
   ```

4. **Fill in the required values** from the parameters table, then deploy the cluster.

5. **Verify the deployment:**

   ```bash
   kubectl get module panfs -n csi-panfs \
     -o custom-columns=NODES:.status.moduleLoader.nodesMatchingSelectorNumber,LOADED:.status.moduleLoader.availableNumber
   kubectl get pods -n csi-panfs -l product=com.vdura.csi.panfs
   kubectl get csidrivers com.vdura.csi.panfs
   kubectl get storageclass csi-panfs-storage-class
   ```

   The node plugin runs only on nodes that carry the `kmm.node.kubernetes.io/csi-panfs.panfs.ready` label. KMM adds that label after it loads the module. If `LOADED` stays at 0, check `kubectl get pods -n csi-panfs` for KMM worker pods with image pull errors. That usually means the registry, DFC version, or kernel mapping is wrong.

6. **Claim a volume:**

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: panfs-data
   spec:
     accessModes: ["ReadWriteMany"]
     storageClassName: csi-panfs-storage-class
     resources:
       requests:
         storage: 10Gi
   ```

### Air-gapped clusters

The public images are listed under `pack.content.images`. The `panfs-dfc` and `panfs-kmm` images come from VDURA's private registry, so mirror them to your local registry yourself. Then point `dfc.privateRegistry`, the kernel mapping, and the registry secret at that mirror.

### Removing the pack

Delete every workload and PVC that uses `csi-panfs-storage-class` before you remove the pack. With the default `Delete` reclaim policy, deleting a PVC also deletes its data on the realm. After you remove the pack, remove the client label from the nodes if you no longer need it.

## Upgrade

- This is the first version of the pack and tracks upstream driver release 1.2.5.
- A new DFC release changes the image tag in both `dfc.version` and the kernel mapping. Update both together.
- For driver upgrades, follow VDURA's [upgrade guide](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/Upgrade.md).

## References

- [VDURA PanFS CSI driver repository](https://github.com/panasasinc/panfs-container-storage-interface-oss)
- [Driver usage guide](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/Usage-Guide.md)
- [KMM integration](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/KMM.md)
- [Encryption](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/Encryption.md)
- [SELinux](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/SELinux.md)
- [Troubleshooting](https://github.com/panasasinc/panfs-container-storage-interface-oss/blob/1.2.5/docs/Troubleshooting.md)
