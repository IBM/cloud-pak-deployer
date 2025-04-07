# Global configuration for Cloud Pak Deployer

## global_config
Cloud Pak Deployer can use properties set in the global configuration (`global_config`) during the deployment process and also as substitution variables in the configuration, such as `{{ env_id}}` and `{{ ibm_cloud_region }}`. 

The following `global_config` variables are automatically copied into a "simple" form so they can be referenced in the configuration file(s) and also overridden using the command line.

| Variable name | Description |
| ------------- | ----------- |
| `environment_name` | Name used to group secrets, typically you will specify `sample` |
| `cloud_platform` | Cloud platform applicable to configuration, such as `ibm-cloud`, `aws`, `azure` |
| `env_id` | Environment ID used in various other configuration objects |
| `ibm_cloud_region` | When Cloud Platform is `ibm-cloud`, the region into which the ROKS cluster is deployed |
| `aws_region` | When Cloud Platform is `aws`, the region into which the ROSA/self-managed OpenShift cluster is deployed |
| `azure_location` | When Cloud Platform is `azure`, the region into which the ARO OpenShift cluster is deployed |
| `universal_admin_user` | User name to be used for admin user (currently not used) |
| `universal_password` | Password to be used for all (admin) users it not specified in the vault |
| `confirm_destroy` | Is destroying of clusters, services/cartridges and instances allowed? |
} `optimize_deploy` | Optimize deployment by skipping components already installed with the correct version? |

For all other variables, you can refer to the qualified form, for example: `"{{ global_config.division }}"`

Sample global configuration:
```
global_config:
  environment_name: sample
  cloud_platform: ibm-cloud
  env_id: pluto-01
  ibm_cloud_region: eu-de
  universal_password: very_secure_Passw0rd$
  confirm_destroy: False
  optimize_deploy: True
```

If you run the `cp-deploy.sh` command and specify `-e env_id=jupiter-03`, this will override the value in the `global_config` object. The same applies to the other variables.