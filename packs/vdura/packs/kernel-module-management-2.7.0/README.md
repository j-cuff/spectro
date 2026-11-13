# Kernel Module Management (KMM)

This pack deploys the [Kernel Module Management](https://kmm.sigs.k8s.io/) operator v2.7.0 from kubernetes-sigs. KMM loads out-of-tree kernel modules on nodes from container images. Each module is described by a `Module` custom resource that maps node kernel versions to images.

The VDURA PanFS CSI Driver pack uses KMM to load the `panfs` kernel module on client nodes.

KMM does not publish a Helm chart, so this pack packages the upstream `config/default` kustomization as a Helm chart. The pack differs from upstream in three ways:

- The namespace is the pack namespace, `kmm-operator-system` by default.
- Images are pinned to the `gcr.io/k8s-staging-kmm` builds of the v2.7.0 release commit, instead of `:latest`.
- CRDs carry `helm.sh/resource-policy: keep`, so removing the pack does not delete existing `Module` objects.

## Prerequisites

- The **cert-manager** pack, placed below this pack in the cluster profile. KMM's webhook uses a cert-manager `Issuer` and `Certificate`.

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `charts.kernel-module-management.images.operator` | Operator image | v2.7.0 commit build |
| `charts.kernel-module-management.images.webhookServer` | Webhook server image | v2.7.0 commit build |
| `charts.kernel-module-management.images.worker` | Worker image that loads modules on nodes | v2.7.0 commit build |
| `charts.kernel-module-management.images.signer` | Module signing image (used only for in-cluster signing) | v2.7.0 commit build |
| `charts.kernel-module-management.images.builder` | Kaniko image (used only for in-cluster module builds) | `v1.23.2` |

## Usage

Add this pack above cert-manager and below any pack that creates `Module` objects. Check the operator after the cluster deploys:

```bash
kubectl get pods -n kmm-operator-system
kubectl get crd modules.kmm.sigs.x-k8s.io
```

## Upgrade

To build a new version, set `KMM_REF` and `KMM_IMAGE_TAG` in `scripts/build.sh`. Also update the image tags in this pack's values and in `charts-src/kernel-module-management/values.yaml`, then rebuild. Find the image tag for a release by listing the staging tags that contain its commit hash:

```bash
crane ls gcr.io/k8s-staging-kmm/kernel-module-management-operator | grep <short-sha>
```

## References

- [KMM documentation](https://kmm.sigs.k8s.io/)
- [KMM source](https://github.com/kubernetes-sigs/kernel-module-management)
