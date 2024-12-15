# Post-run changes
If you want to change the deployed configuration, you can just update the configuration files and re-run the deployer. Make sure that you use the same input configuration and status directories and also the `env_id` if you specified one, otherwise deployment may fail.

Below are a couple of examples of post-run changes you may want to do.

## Change Cloud Pak for Data admin password
When initially installed, the Cloud Pak Deployer will generate a strong password for the Cloud Pak for Data `admin` user (or `cpadmin` if you have selected to use Foundational Services IAM). If you want to change the password afterwards, you can do this from the Cloud Pak for Data user interface, but this means that the deployer will no longer be able to make changes to the Cloud Pak for Data configuration.

If you have updated the admin password from the UI, please make sure you also update the secret in the vault.

First, list the secrets in the vault:
``` { .bash .copy }
./cp-deploy.sh vault list
```

This will show something similar to the following:
```output
Secret list for group sample:
- ibm_cp_entitlement_key
- sample-provision-ssh-key
- sample-provision-ssh-pub-key
- sample-terraform-tfstate
- cp4d_admin_zen_sample_sample
```

Then, update the password:
``` { .bash .copy }
./cp-deploy.sh vault set -vs cp4d_admin_zen_sample_sample -vsv "my Really Sec3re Passw0rd"
```

Finally, run the deployer again. It will make the necessary changes to the OpenShift secret and check that the `admin` (or `cpadmin`) user can log in. In this case you can speed up the process via the `--skip-infra` flag.
``` { .bash .copy }
./cp-deploy.sh env apply --skip-infra [--accept-all-liceneses]
```

## Add GPU nodes to the cluster
watsonx.ai requires GPUs to run and tune the foundation models. Deployer currently does not provision these GPU nodes, but you can add them manually from the OpenShift console.

### GPU nodes on AWS
For adding GPU nodes on AWS infrastructure, refer to [Add GPUs to self-managed OpenShift on AWS](./aws-self-managed-add-gpu.md).

### GPU nodes on Azure
For adding GPU nodes on Azure infrastructure, refer to [Add GPUs to self-managed OpenShift on Azure](./azure-self-managed-add-gpu.md).