---
title: Apply OpenShift node settings when machine config operator does not exist
---
# Apply OpenShift node settings when machine config operator does not exist

Cloud Pak Deployer automatically applies cluster and node settings before installing the Cloud Pak(s). Sometimes you may also want to automate applying these node settings without installing the Cloud Pak. For convenience, the repository includes a script that makes the same changes normally done through automation: `scripts/cp4d/cp4d-apply-non-mco-cluster-settings.sh`.

To apply the node settings, do the following:

* If images are pulled from the entitled registry, set the `CP_ENTITLEMENT_KEY` environment variable
* If images are to be pulled from a private registry, set both the `CPD_PRIVATE_REGISTRY` and ``CPD_PRIVATE_REGISTRY_CREDS`` environment variables
* Log in to the OpenShift cluster with **cluster-admin** permissions
* Run the `scripts/cp4d/cp4d-apply-non-mco-cluster-settings.sh` script.


The `CPD_PRIVATE_REGISTRY` value must reference the registry host name and optionally the port and namespace that must prefix the images. For example, if the images are kept in https://de.icr.io/cp4d-470, you must specify `de.icr.io/cp4d-470` for the `CPD_PRIVATE_REGISTRY` environment variable. If images are kept in https://cust-reg:5000, you must specify `cust-reg:5000` for the `CPD_PRIVATE_REGISTRY` environment variable.

For the `CPD_PRIVATE_REGISTRY_CREDS` value, specify both the user and password in a single string, separated by a colon (`:`). For example: `admin:secret_passw0rd`.

!!!warning
    When setting the private registry and its credentials, the script automatically creates the configuration that will set up ImageContentSourcePolicy and global pull secret alternatives. This change cannot be undone using the script. It is not possible to set the private registry and later change to entitled registry. Changing the private registry's credentials can be done by re-running the script with the new credentials.


## Example

```
export CPD_PRIVATE_REGISTRY=de.icr.io/cp4d-470
export CPD_PRIVATE_REGISTRY_CREDS="iamapikey:U97KLPYF663AE4XAQL0"
./scripts/cp4d/cp4d-apply-non-mco-cluster-settings.sh
```

```output
Creating ConfigMaps and secret
configmap "cloud-pak-node-fix-scripts" deleted
configmap/cloud-pak-node-fix-scripts created
configmap "cloud-pak-node-fix-config" deleted
configmap/cloud-pak-node-fix-config created
secret "cloud-pak-node-fix-secrets" deleted
secret/cloud-pak-node-fix-secrets created
Setting global pull secret and ICSP for private registry de.icr.io/cp4d-470
configmap/cloud-pak-node-fix-config data updated
Global pull secret will be set for private registry de.icr.io
/tmp/.dockerconfigjson
secret/pull-secret data updated
secret/cloud-pak-node-fix-secrets data updated
Generating kubelet config
Starting pod/102310132-debug ...
To use host binaries, run `chroot /host`

Removing debug pod ...
configmap/cloud-pak-node-fix-config data updated
Generating crio config
Starting pod/102310132-debug ...
To use host binaries, run `chroot /host`

Removing debug pod ...
configmap/cloud-pak-node-fix-config data updated
Generating Tuned config
tuned.tuned.openshift.io/cp4d-ipc unchanged
Writing fix scripts to config map
configmap/cloud-pak-node-fix-scripts data updated
configmap/cloud-pak-node-fix-scripts data updated
Creating service account for DaemonSet
serviceaccount/cloud-pak-crontab-sa unchanged
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:privileged added: "cloud-pak-crontab-sa"
Recreate DaemonSet
daemonset.apps "cloud-pak-crontab-ds" deleted
daemonset.apps/cloud-pak-crontab-ds created
Showing running DaemonSet pods
NAME                         READY   STATUS        RESTARTS   AGE
cloud-pak-crontab-ds-bvjzl   0/1     Pending       0          1s
cloud-pak-crontab-ds-dq7mb   1/1     Terminating   0          85s
cloud-pak-crontab-ds-pl7cz   0/1     Pending       0          0s
cloud-pak-crontab-ds-ql975   1/1     Terminating   0          85s
cloud-pak-crontab-ds-rrrbf   0/1     Pending       0          0s
cloud-pak-crontab-ds-tz5tl   1/1     Terminating   0          85s
Waiting for 5 seconds for pods to start
Showing running DaemonSet pods
NAME                         READY   STATUS        RESTARTS   AGE
cloud-pak-crontab-ds-bvjzl   0/1     Pending       0          6s
cloud-pak-crontab-ds-dq7mb   1/1     Terminating   0          90s
cloud-pak-crontab-ds-pl7cz   0/1     Pending       0          5s
cloud-pak-crontab-ds-ql975   1/1     Terminating   0          90s
cloud-pak-crontab-ds-rrrbf   0/1     Pending       0          5s
cloud-pak-crontab-ds-tz5tl   1/1     Terminating   0          90s
```