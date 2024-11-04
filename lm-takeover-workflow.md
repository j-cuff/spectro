- From: git clone https://github.com/j-cuff/spectro.git
# SpectroCloud Cluster Takeover Procedure
> ### Utilize the Runbook as the source of truth
- [Runbook](Runbook.md)
- https://docs.google.com/document/d/1BMvVPqmgnBNipwGqcMTLnRaM3BDTVPijYSmMowDH29E (internal)
> ### Upgrade Palette Vertex to the latest available version
- This allows for all bug fixes, security updates, and features to be utilized for the takeover.
- Current Required Version = 4.5.4
## Discovery & Cloud Preparation
- See Runbook
## Pre-takeover Readiness & Preparation
> ### Perform Cluster Backup Procedures
- Follow current internal processes for the cluster backups
- Create backup of Takeover Cluster
- Create backup of TKG-Management Cluster

## Prepare IDE Environment for Takeover
> ### EDIT and SET Name of the cluster being taken over
- ```shell
  export TC_NAME=<takeover-cluster-name>
  ```
> ### Create working directory: $HOME/workspace/spectro
- This is important for the flow of this document  
- ```shell
  mkdir -p $HOME/workspace/spectro
  ```
> ### SET Full Path to Takeover Cluster Admin Kubeconfig
- Move Takeover Cluster Admin KubeConfig to \$HOME/workspace/spectro/tc-admin-kube.config  
- ```shell
  export TC_ADMIN_KUBECONFIG="$HOME/workspace/spectro/tc-admin-kube.config"
  ```
> ### SET Full Path to TKG-MGMT Cluster Admin Kubeconfig
- Move TKG-MGMT Cluster Admin KubeConfig to \$HOME/workspace/spectro/tkg-mgmt-kube.config  
- ```shell
  export TKG_MGMT_KUBECONFIG="$HOME/workspace/spectro/tkg-mgmt-kube.config"
  ```
> ### Palette FQDN (ex. vertex.mydomain.com)
- ```shell
  export PALETTE_URL=palette.takeover.global.lmco.com
  ```
> ### Create Dir structure, Extract takeover files, set TAKEOVER_ROOT
- single command below  
- ```shell
  mkdir -p $HOME/workspace/spectro/$TC_NAME && tar -xvf $HOME/workspace/spectro/takeoverfiles.tar.gz -C $HOME/workspace/spectro/$TC_NAME && cd $HOME/workspace/spectro/$TC_NAME/takeover-files && export TAKEOVER_ROOT=$(pwd) && echo $TAKEOVER_ROOT && echo "SUCCESS" || echo "ERROR"
  ```
> ### Setup palettectl cli, add it to the PATH
- Note: This should be run from linux server  
- ```shell
  cp $TAKEOVER_ROOT/bin/palettectl-$(arch) $TAKEOVER_ROOT/bin/palettectl && chmod +x $TAKEOVER_ROOT/bin/palettectl && export PATH=$PATH:$TAKEOVER_ROOT/bin/ && echo "SUCCESS" || echo "ERROR"
  ```
> ### Create clusterctl.yaml file 
- ```shell
  echo -e "overridesFolder: $TAKEOVER_ROOT/overrides\n\n\nCLUSTERCTL_LOG_LEVEL: 5" > $TAKEOVER_ROOT/clusterctl.yaml
  ```
## Prepare Takeover Source Cluster and TKG-MGMT Cluster Resources
> ### SWITCH to TKG-MGMT Cluster Context
- ```shell
  export KUBECONFIG=$TKG_MGMT_KUBECONFIG
  kubectl config get-contexts
  ```
- Validate TKG-MGMT Cluster Context is set  

> ### AS TKG-MGMT Context: Validate TKG-MGMT Cluster is managing the Takeover Cluster
- ```shell
  CLS_NAME=$(kubectl get cluster $TC_NAME -o=jsonpath='{.spec.infrastructureRef.name}') && echo "Found: $CLS_NAME" || echo "NotFound: ERROR"
  CLS_NAMESPACE=$(kubectl get cluster $TC_NAME -o=jsonpath='{.spec.infrastructureRef.namespace}') && echo "Found: $CLS_NAMESPACE" || echo "Not Found: ERROR"
  ```
> ### AS TKG-MGMT Context: Delete Autoscaler Deployment for Takoever Cluster from TKG-MGMT if it exists
- ```shell
  kubectl get deployments | grep autoscaler | grep $CLS_NAME
  ```
- If it exists:
- ```shell
  kubectl delete deployment $CLS_NAME-cluser-autoscaler -n $CLS_NAMESPACE
  ```
## Begin Takeover Procedures
> ### Export Cluster Templates from TKG-MGMT Cluster 
- ```shell
  $TAKEOVER_ROOT/bin/palettectl move -n $CLS_NAMESPACE --clusterName $CLS_NAME --to-template-directory $TAKEOVER_ROOT/takeover-templates
  ```
> ### Verify and Clean all Takeover Template Files ( >> )
- ```shell
  code $TAKEOVER_ROOT/takeover-templates
  ```
> ### Generate API Payload to Register a Ghost Cluster with Palette within the Palette GUI
| Order | Command     | Action                           |
|-------|-------------|----------------------------------|
| 1     | **Select:** | TECH PREVIEW / AWS Takeover Test |
| 2     | **Click:**  | Start Configuration |
Basic Information  
| 3     | **Enter:**  | Cluster Name as $CLS_NAME |
| 4     | **Select:** | Cloud Account |
| 5     | **Click:**  | Next |
Cluster Profile
| 6     | **Click:**  | Add Cluster Profile |
| 7     | **Select:** | Infra Profile Name |
| 8     | **Click:**  | Confirm / Next  |
Cluster Config Macros
| 9     | **Copy/Paste:** | Replace contents of __Cluster configuration__ window in UI with clipboard output of pbcopy cmd  |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/ClusterTemplate.yaml``` |
|       | **Enter:**      | AWS_REGION #from clustertemplate.yaml |
|       | **Enter:**      | AWS_SSH_KEY_NAME #from clustertemplate.yaml |
Nodes Config - NodePools<br>CONTROL-PLANE-POOL CONFIG
| 10    | **Copy/Paste:** | Replace contents of __Node pool configuration__ window in UI with clipboard output of pbcopy cmd  |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/ControlPlaneTemplate.yaml```   |
|       | **Enter:**      | Kubernetes_Version, AMI_ID, Control Plane Machine Type #from ControlPlaneTemplate.yaml |
Nodes Config - NodePools<br>WORKER-POOL-CONFIG
| 11    | **Copy/Paste:** | Replace contents of __Node pool configuration__ window in UI with clipboard output of pbcopy cmd  |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-0.yaml``` |
|       | **Enter:**      | Kubernetes_Version, AMI_ID, Control Plane Machine Type #from WorkerTemplate-0.yaml |
|       | **REPEAT:**     | Repeat step 11 for each WorkerTemplate-x.yaml by clicking "Add Node Pool" |
|       |                 | **If Necessary** |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-1.yaml``` |
|       |                 | <CLS_NAME>-md-1; paste clipboard into Node Pool Configuration window |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-2.yaml``` |
|       |                 | <CLS_NAME>-md-2; paste clipboard into Node Pool Configuration window |
DO NOT CLICK NEXT
| 12    | **Click:**      | Click the API button (Top Right Corner) and copy out the raw json payload. |
|       |                 | This will be used as the body for a POST API Call |
```
1.  pbcopy < $TAKEOVER_ROOT/takeover-templates/ClusterTemplate.yaml
2.  pbcopy < $TAKEOVER_ROOT/takeover-templates/ControlPlaneTemplate.yaml
3.  pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-0.yaml
IF Necessary:
4.  pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-1.yaml
5.  pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-2.yaml
```
- Edit Payload to include:  
``` "clusterType": "PureAttach", ``` immediately under spec:   
- Edit Payload to include:  
``` "patchOnBoot": false, ``` and ``` "rebootIfRequired": false ```

## POST JSON Payload to palette api
```
curl statement
```
- Verify success (201) as well as a CID.  Copy CID and set to CL_UID var.
```
CL_UID="paste from POST result"
```
## Switch to Takeover Cluster Context:
```
export KUBECONFIG=$TC_ADMIN_KUBECONFIG
kubectl config get-contexts
```
- Validate Takeover Cluster Context
## Install CAPI Components into the Takeover Cluster
```
kubectl create ns cluster-$CL_UID  
kubectl annotate ns cluster-$CL_UID clusterEnv=target

export AWS_REGION=us-east-1  
export AWS_ACCESS_KEY_ID="tkg-provisioner ACCESS KEY"  
export AWS_SECRET_ACCESS_KEY="tkg-provsioner SECRET ACCESS KEY"  
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

clusterctl init --infrastructure=aws:v2.0.2 --core cluster-api:v1.5.3 --control-plane kubeadm:v1.5.3 --bootstrap kubeadm:v1.5.3 --config $TAKEOVER_ROOT/clusterctl.yaml
```
## SWITCH to TKG-MGMT Cluster Context
```
export KUBECONFIG=$TKG_MGMT_KUBECONFIG  
kubectl config get-contexts  
```
- Validate TKG-MGMT Cluster Context

## PIVOT AS TKG-MGMT Cluster Context
```
palettectl move -n $CLS_NAMESPACE --clusterName=$TC_NAME --to-namespace cluster-$CL_UID --to-kubeconfig=$TC_ADMIN_KUBECONFIG
```
## Switch to Takeover Cluster Context
```
export KUBECONFIG=$TC_ADMIN_KUBECONFIG  
kubectl config get-contexts
```
- Validate Takeover Cluster Context
## Complete Takeover Process by Applying SpectroCluster Manifest to Takeover Cluster
AS TAKEOVER CLUSTER CONTEXT  
```
kubectl apply -f https://$PALETTE_URL/v1/spectroclusters/$CL_UID/import/manifest
```

# Validation

PROJECT_UID="<projectid>"
AUTH_TOKEN="ey..."
API_PAYLOAD_FILE="/Full/Path"

curl --location 'https://$PALETTE_URL/v1/spectroclusters/cloudTypes/awstkg?ProjectUid=$PROJECT_UID' \
  --header 'Authorization: $AUTH_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '@api-payload.json'


