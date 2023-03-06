# Global configuration for Cloud Pak Deployer

## global_config
Cloud Pak Deployer can use properties set in the global configuration (`global_config`) during the deployment process and also as substitution variables in the configuration, such as `"{{ ibm_cloud_region }}"`. 

The following `global_config` variables are automatically copied into a "simple" form:
* `environment_name`: Name used to group secrets, typically you will specify `sample`
* `cloud_platform`: Cloud platform applicable to configuration, such as `ibm-cloud`, `aws`, `azure`
* `ibm_cloud_region`: When Cloud Platform is `ibm-cloud`, the region into which the ROKS cluster is deployed
* `aws_region`: When Cloud Platform is `aws`, the region into which the ROSA/self-managed OpenShift cluster is deployed
* `azure_location`: When Cloud Platform is `azure`, the region into which the ARO OpenShift cluster is deployed
* `universal_admin_user`: User name to be used for admin user (currently not used)
* `universal_password`: Password to be used for all (admin) users it not specified in the vault

For all other variables, you can refer to the qualified form, for example: `"{{ global_config.env_id }}"`

Sample global configuration:
```
global_config:
  environment_name: sample
  cloud_platform: ibm-cloud
  ibm_cloud_region: eu-de
  universal_password: very_secure_Passw0rd$
```