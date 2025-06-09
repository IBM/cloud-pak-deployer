# Configuring IBM Storage for OpenShift

You can configure IBM Storage Fusion for OpenShift using Cloud Pak Deployer.

IBM Storage for a particular OpenShift cluster is configured like this:
```
---
ibm_storage:
- openshift_cluster_name: "{{ env_id }}"
  backup_restore:
    install: True
```

#### Property explanation
| Property       | Description                                                                            | Mandatory | Allowed values |
| -------------- | -------------------------------------------------------------------------------------- | --------- | -------------- |
| ibm_storage[]  | List IBM Storage definitions, one for each OpenShift cluster                           | No        |                |
| openshift_cluster_name | Name of the OpenShift cluster. If not specified and there is only one OpenShift cluster, it will be selected automatically | No        |                |
| backup_restore | Specification of the Backup & Restore component                                        | No        |                |
| .install       | Select whether or not to install the Backup & Restore component                        | No        | False (default), True |