# Utilize the Runbook as the source of truth
- https://docs.google.com/document/d/1BMvVPqmgnBNipwGqcMTLnRaM3BDTVPijYSmMowDH29E (internal)
# Upgrade Palette Vertex to the latest available version
- This allows for all bug fixes, security updates, and features to be utilized for the takeover.
 
# Discovery & Cloud Preparation
- See Runbook
# Pre-takeover Readiness & Preparation
>## 1. Perform a Cluster Backup procedure
1. Perform a velero backup on this cluster as well as the TKG MGMT Cluster to recover in case of failure.
    - Follow internal processes for the backup
 
>## 2. Validate Prereqs
Proxy info
- Test for prereqs cli's (kubectl, jq, clusterctl, clusterawsadm, cluster profile, aws cloud account)
  - External Sites
    | Tool | Link |
    | - | - |
    | Install Clusterctl | https://cluster-api.sigs.k8s.io/user/quick-start.html |
    | Install Kubectl    | https://kubernetes.io/docs/tasks/tools/ |
    | Install JQ         | https://jqlang.github.io/jq/download/ |
    | Install AWS CLI    | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
    | Setup AWS Profiles | If Necessary, See Footnote |
 
- Validate **ADMIN** kubeconfigs and MFA authentication for TKG Source and TKG MGMT Clusters
  - Switching contexts: konfig (https://github.com/corneliusweig/konfig), kubectx (https://github.com/ahmetb/kubectx)
 
- AWS IAM User / Policies and Roles (Use the tkg-provisioner IAM acct)
  - https://docs.spectrocloud.com/clusters/public-cloud/aws/required-iam-policies/
 
- >[!WARNING] Pause ALL Rancher Fleet Deployments to the Source Cluster
  - Alternatively you can scale down the fleet agent to 0
  - **AS SOURCE CLUSTER CONTEXT:** ```kubectl scale --replicas=0 deploy/fleet-agent -n cattle-fleet-system```
- >[!WARNING] Make sure cluster-autoscaler is not installed for the Source cluster
  - **AS TKG-MGMT CLUSTER CONTEXT:** ```kubectl get deployments | grep autoscaler:``` should return ```No resources found```.
  - if it does not, delete the deployment associated with the SOURCE cluster from the MGMT cluster
 
> ## 3. Custom Cloud Type installation and validation
1. See Runbook
> ## 4. Create an Infrastructure Cluster Profile
1. See Runbook or See #2 below.
2. Import cluster profile from provided json file
    - Requirements:
      - setup robot account to harbor.global.lmco.com project lmc.eo.force.palette-packs
      - create oci registry within palette named lm-harbor, choose Pack Provider, Basic Auth, Sync, Endpoint https://harbor.global.lmco.com, lmc.eo.force.palette-packs BCP
# Takeover Inception
> ## 1. Extract takoverfiles.zip
- Extract the contents of the provided zip file to a working directory on the jumpbox|bastion|workstation
  - example ~/workspace/takeover-clustername (make this directory if you wish, then ```cd ~/workspace/takeover-clustername```)
  ```
  mkdir takeover-files && tar -xvf takeoverfiles.tar.gz && cd takeover-files && export TAKEOVER_ROOT=$(pwd) && echo $TAKEOVER_ROOT && echo "SUCCESS" || echo "ERROR"
  ```
> ## 2. Cluster Authentication and takeover IDE environment setup
- Open iTerm2 and create 2 Sessions in tab format. Name one 'TKG-SOURCE' and the other 'TKG-MGMT'.
- In the TKG-SOURCE, auth to Source Cluster with admin kubeconfig : ```export KUBECONFIG=~/workspace/<clustername>/<source_cluster_admin_kubeconfig>```
- In the TKG-MGMT, auth to MGMT Cluster with admin kubeconfig : ```export KUBECONFIG=~/workspace/<clustername>/<source_mgmtcluster_admin_kubeconfig>```
 
> ## 3. Establish architecture for palettectl command
- Execute the command below to setup the appropriate palettectl cli for your architecture.  
  ```
  cp $TAKEOVER_ROOT/bin/palettectl-$(arch) $TAKEOVER_ROOT/bin/palettectl && chmod +x $TAKEOVER_ROOT/bin/palettectl && export PATH=$PATH:$TAKEOVER_ROOT/bin/ && echo "SUCCESS" || echo "ERROR"  
  echo "Execute the command below on the TKG-MGMT Terminal" && echo -e "export TAKEOVER_ROOT=$TAKEOVER_ROOT"
  ```
> ## 4. Create clusterctl.yaml
- Execute the command below to create the pointer to the overrides folder
  ```
  echo -e "overridesFolder: $TAKEOVER_ROOT/overrides\n\n\nCLUSTERCTL_LOG_LEVEL: 5" > $TAKEOVER_ROOT/clusterctl.yaml
  ```  
> ## 5. Validate Source Cluster name and namespace | MGMT Cluster Context
- Fill out INPUT_CLS_NAME with the TKG Source Cluster Name, then execute.  
  ```
  export INPUT_CLS_NAME="<cluster name here>"
  ```  
- Execute the below commands by copying and pasting into terminal
  > [!NOTE] Validate Name / namespace output!
  ```
  export CLS_NAME=$(kubectl get cluster $INPUT_CLS_NAME -o=jsonpath='{.spec.infrastructureRef.name}')
  export CLS_NAMESPACE=$(kubectl get cluster $INPUT_CLS_NAME -o=jsonpath='{.spec.infrastructureRef.namespace}')
  echo -e "Cluster-Name = $CLS_NAME" && echo -e "Cluster-NameSpace = $CLS_NAMESPACE" | column -t kjl
  ```  
> ## 6. Generate Cluster, Control Plane, and Worker Node Templates | MGMT Cluster Context
- The following ```palettectl move``` command will:
  1. Discover Cluster API objects for cluster="CLS_NAME" namespace="CLS_NAMESPACE"
  1. Save template files to directory $TAKEOVER_ROOT/takeover-templates
  1. [!WARNING] Validate all yaml files in takeover-templates directory
  ```
  $TAKEOVER_ROOT/bin/palettectl move -n $CLS_NAMESPACE --clusterName $CLS_NAME --to-template-directory $TAKEOVER_ROOT/takeover-templates
  ```  
- If you have VS Code installed in the path, you can execute the command below to open the folder for validation. (cmd-shift-p 'shell command')
  ```
  code $TAKEOVER_ROOT/takeover-templates
  ```
  - Validate there are no errors or bad yaml (may search for ">>")  
> ## 7. Pallete UI : As Tenant Admin: Clusters: Create Cluster or Add New Cluster
  
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
Nodes Config - NodePools<br>CONTROL-PLANE-POOL CONFIGURATION
| 10    | **Copy/Paste:** | Replace contents of __Node pool configuration__ window in UI with clipboard output of pbcopy cmd  |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/ControlPlaneTemplate.yaml```   |
|       | **Enter:**      | Kubernetes_Version, AMI_ID, Control Plane Machine Type #from ControlPlaneTemplate.yaml |
Nodes Config - NodePools<br>WORKER-POOL-CONFIGURATION
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
 
## 8. Register Cluster with Palette API POST
- Edit the payload as json formated file, and add a new line as first new line in the spec section, as follows:
- ```"clusterType": "PureAttach",```
- Register the cluster with a POST API on: https://<your-Palette-FQDN>/v1/spectroclusters/cloudTypes/awstko?ProjectUid=<your-project-UID>
  with the previous modified payload in the 'body'. (POSTMAN / CURL)<br>
  https://gist.github.com/ungoldman/11282441 (curl --oauth2-bearer $token --json @FILENAME DESTINATION)<br>
  Note: Project UID can be retrieved from the Projects page in Palette.<br>
  will need an authorization token retrieved from palete ui network inspection export TOKEN="ey..."
- Get the cluster UID from the response of the POST request and save it somewhere special.
 
# Onboarding & Rollout
> ## Installing CAPI into the Source Cluster:
- Verify kubernetes context is to the TKG-SOURCE cluster
```
export CL_UID=671a8f19cbe5806b9cf02a9c
kubectl create ns cluster-$CL_UID
kubectl annotate ns cluster-$CL_UID clusterEnv=target
export AWS_REGION=<region>
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_SESSION_TOKEN=<session-token>
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
clusterctl init --infrastructure=aws:v2.0.2 --core cluster-api:v1.5.3 --control-plane kubeadm:v1.5.3 --bootstrap kubeadm:v1.5.3 --config $TAKEOVER_ROOT/clusterctl.yaml
```
> ## PIVOT | TKG-MGMT Context
- palettectl move -n default --clusterName=ptest-1n --to-namespace cluster-670eacaa2e5a97f666862c3d --to-kubeconfig=/Users/n2165f/workspace/ptest-1n/admin-ptest-1n.config
> ## PIVOT | TKG-SOURCE Context
- kubectl apply -f https://palette.takeover.global.lmco.com/v1/spectroclusters/$CL_UID/import/manifest
 
 
## All Commands in a single code-block
```
Workstation:
mkdir takeover-files && tar -xvf takeoverfiles.tar.gz && cd takeover-files && export TAKEOVER_ROOT=$(pwd) && echo $TAKEOVER_ROOT && echo "SUCCESS" || echo "ERROR"
cp $TAKEOVER_ROOT/bin/palettectl-$(arch) $TAKEOVER_ROOT/bin/palettectl && chmod +x $TAKEOVER_ROOT/bin/palettectl && export PATH=$PATH:$TAKEOVER_ROOT/bin/ && echo "SUCCESS" || echo "ERROR"
echo -e "overridesFolder: $TAKEOVER_ROOT/overrides\n\n\nCLUSTERCTL_LOG_LEVEL: 5" > $TAKEOVER_ROOT/clusterctl.yaml
TKG-MGMT Cluster Context:
export INPUT_CLS_NAME="<cluster name here>"
export CLS_NAME=$(kubectl get cluster $INPUT_CLS_NAME -o=jsonpath='{.spec.infrastructureRef.name}')
export CLS_NAMESPACE=$(kubectl get cluster $INPUT_CLS_NAME -o=jsonpath='{.spec.infrastructureRef.namespace}')
echo -e "Cluster-Name = $CLS_NAME" && echo -e "Cluster-NameSpace = $CLS_NAMESPACE" | column -t
$TAKEOVER_ROOT/bin/palettectl move -n $CLS_NAMESPACE --clusterName $CLS_NAME --to-template-directory $TAKEOVER_ROOT/takeover-templates
code $TAKEOVER_ROOT/takeover-templates
 
pbcopy < $TAKEOVER_ROOT/takeover-templates/ClusterTemplate.yaml
pbcopy < $TAKEOVER_ROOT/takeover-templates/ControlPlaneTemplate.yaml
pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-0.yaml
pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-1.yaml
pbcopy < $TAKEOVER_ROOT/takeover-templates/WorkerTemplate-2.yaml
 
curl --oauth2-bearer $token --json @FILENAME/OF/JSON_BODY https://palette.takeover.global.lmco.com/v1/spectroclusters/cloudTypes/awstkg?ProjectUid=<project UID>
 
export CL_UID="670eacaa2e5a97f666862c3d"
kubectl create ns cluster-$CL_UID
kubectl annotate ns cluster-$CL_UID clusterEnv=target
export AWS_REGION=<region>
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_SESSION_TOKEN=<session-token>
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
clusterctl init --infrastructure=aws:v2.0.2 --core cluster-api:v1.5.3 --control-plane kubeadm:v1.5.3 --bootstrap kubeadm:v1.5.3 --config $TAKEOVER_ROOT/clusterctl.yaml
 
palettectl move -n default --clusterName=$CLS_NAME --to-namespace cluster-$CL_UID --to-kubeconfig=/Users/n2165f/workspace/ptest-1n/admin-ptest-1n.config
kubectl apply -f https://api.dev.spectrocloud.com/v1/spectroclusters/$CL_UID/import/manifest
```
 
# Footnotes
>## AWS Commands
```
aws configure --profile palette
aws configure --profile tkg-provisioner
aws ec2 describe-instances --profile user1
export AWS_PROFILE=user1
aws configure list
aws configure get
aws configure set region us-west-2 --profile palette
aws sts get-session-token --no-verify-ssl --profile tkg-provisioner
~/.aws/credentials
~/.aws/config
```
 
# Additional Gotcha's
> ## API Generation
In the cluster settings page:
OS patching > No
Patch OS on boot > No
Reboot if required > No
Scans > No
Backups > No
RBAC > No

create file to read from with 

echo "Enter Takeover Cluster Name:"
read TC_NAME
echo "Enter Full Path to Takeover Cluster Admin KubeConfig:"
read TC_ADMIN_KUBECONFIG

mkdir $HOME/workspace/spectro
git pull <takeoverfiles>
set vars
execute scriptblock

Things to work on


git clone https://github.com/j-cuff/spectro.git
---
---
---
# SpectroCloud Cluster Takeover Procedure
## Utilize the Runbook as the source of truth
- [Runbook](Runbook.md)
- https://docs.google.com/document/d/1BMvVPqmgnBNipwGqcMTLnRaM3BDTVPijYSmMowDH29E (internal)
## Upgrade Palette Vertex to the latest available version
- This allows for all bug fixes, security updates, and features to be utilized for the takeover.
- Current Required Version = 4.5.4

## Discovery & Cloud Preparation
- See Runbook
## Pre-takeover Readiness & Preparation
## Perform Cluster Backup Procedures
- Takeover Cluster
- TKG Management Cluster
   on this cluster as well as the TKG MGMT Cluster to recover in case of failure.
    - Follow internal processes for the backup

## EDIT and SET Name of the cluster being taken over
```
TC_NAME=<takeover-cluster-name>
```
## SET Full Path to Takeover Cluster Admin Kubeconfig
```
TC_ADMIN_KUBECONFIG="$HOME/workspace/spectro/tc-admin-kube.config"
```
## SET Full Path to TKG-MGMT Cluster Admin Kubeconfig
```
TKG_MGMT_KUBECONFIG="$HOME/workspace/spectro/tkg-mgmt-kube.config"
```
## Palette FQDN (ex. vertex.mydomain.com)
```
PALETTE_URL=palette.takeover.global.lmco.com
```
## Create Dir structure, Extract takeover files, set TAKEOVER_ROOT
```
single command below

mkdir -p $HOME/workspace/spectro/$TC_NAME && tar -xvf $HOME/workspace/spectro/takeoverfiles.tar.gz -C $HOME/workspace/spectro/$TC_NAME && cd $HOME/workspace/spectro/$TC_NAME/takeover-files && export TAKEOVER_ROOT=$(pwd) && echo $TAKEOVER_ROOT && echo "SUCCESS" || echo "ERROR"
```
## Setup palettectl cli, add it to the PATH
```
cp $TAKEOVER_ROOT/bin/palettectl-$(arch) $TAKEOVER_ROOT/bin/palettectl && chmod +x $TAKEOVER_ROOT/bin/palettectl && export PATH=$PATH:$TAKEOVER_ROOT/bin/ && echo "SUCCESS" || echo "ERROR"
```
## Create clusterctl.yaml file 
```
echo -e "overridesFolder: $TAKEOVER_ROOT/overrides\n\n\nCLUSTERCTL_LOG_LEVEL: 5" > $TAKEOVER_ROOT/clusterctl.yaml
```
## SWITCH to TKG-MGMT Cluster Context
```
export KUBECONFIG=$TKG_MGMT_KUBECONFIG
kubectl config get-contexts
```
- Validate TKG-MGMT Cluster Context is set

## Verify TKG-MGMT Cluster is managing the Takeover Cluster
```
CLS_NAME=$(kubectl get cluster $TC_NAME -o=jsonpath='{.spec.infrastructureRef.name}') && echo "Found: $CLS_NAME" || echo "Found: ERROR"
CLS_NAMESPACE=$(kubectl get cluster $TC_NAME -o=jsonpath='{.spec.infrastructureRef.namespace}') && echo "Found: $CLS_NAMESPACE" || echo "Found: ERROR"
```
## Delete Autoscaler Deployment for Takoever Cluser if it exists
```
kubectl get deployments | grep autoscaler | grep $CLS_NAME
```
- If it exists:
  ```
  kubectl delete deployment $CLS_NAME-cluser-autoscaler -n $CLS_NAMESPACE
  ```
## Export Cluster Templates from TKG-MGMT Cluster 
```
$TAKEOVER_ROOT/bin/palettectl move -n $CLS_NAMESPACE --clusterName $CLS_NAME --to-template-directory $TAKEOVER_ROOT/takeover-templates
```
## Verify and Clean all Takeover Template Files ( >> )
```
code $TAKEOVER_ROOT/takeover-templates
```
## Generate API Payload to Register a Ghost Cluster with Palette within the Palette GUI
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
Nodes Config - NodePools<br>CONTROL-PLANE-POOL CONFIGURATION
| 10    | **Copy/Paste:** | Replace contents of __Node pool configuration__ window in UI with clipboard output of pbcopy cmd  |
|       |                 | ```pbcopy < $TAKEOVER_ROOT/takeover-templates/ControlPlaneTemplate.yaml```   |
|       | **Enter:**      | Kubernetes_Version, AMI_ID, Control Plane Machine Type #from ControlPlaneTemplate.yaml |
Nodes Config - NodePools<br>WORKER-POOL-CONFIGURATION
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


