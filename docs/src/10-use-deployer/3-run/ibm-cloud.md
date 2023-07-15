# Running the Cloud Pak Deployer on IBM Cloud

See the deployer in action in this video: https://ibm.box.com/v/cpd-ibm-cloud-roks

## Topology

A typical setup of the ROKS cluster on IBM Cloud VPC is pictured below:
![ROKS configuration](images/ibm-roks-ocs.png)

## Create an IBM Cloud API Key

In order for the Cloud Pak Deployer to create the infrastructure and deploy IBM Cloud Pak for Data, it must perform tasks on IBM Cloud. In order to do so it requires an IBM Cloud API Key. This can be created by following these steps:

- Go to https://cloud.ibm.com/iam/apikeys and login with your IBMid credentials
- Ensure you have selected the correct IBM Cloud Account for which you wish to use the Cloud Pak Deployer
- Click **Create an IBM Cloud API Key** and provide a name and description
- Copy the IBM Cloud API key using the **Copy** button and store it in a safe place, as you will not be able to retrieve it later

!!! warning
    You can choose to download the API key for later reference. However, when we reference the API key, we mean the IBM Cloud API key as a 40+ character string.

## Acquire an IBM Cloud Pak Entitlement Key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMid credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

## Prepare for running

### Set environment variables for IBM Cloud
Set the environment variables specific to IBM Cloud deployments.
```
export IBM_CLOUD_API_KEY=your_api_key
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

- `IBM_CLOUD_API_KEY`: This is the API key you generated using your IBM Cloud account, this is a 40+ character string
- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string

### Set deployer status directory
Cloud Pak Deployer uses the status directory to log its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. 

```
export STATUS_DIR=$HOME/cpd-status
```

- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files. **Please note** that if you have chosen to use a File Vault, the properties file is keps under the `vault` directory within the status directory. If you don't specify a status directory, it is assumted to be `$HOME/cpd-status`.

### Set deployer configuration location
You can use a local directory to hold the deployer configuration or retrieve the configuration from a GitHub repository. If you don't specify any configuration directory or GitHub repository, the configuration directory are assumed to be `$HOME/cpd-config`.
```
export CONFIG_DIR=$HOME/cpd-config
```

- `CONFIG_DIR`: Directory that holds the configuration, it must have a `config` subdirectory.

Or, when using a GitHub repository for the configuration.
```
export CPD_CONFIG_GIT_REPO="https://github.com/IBM/cloud-pak-deployer-config.git"
export CPD_CONFIG_GIT_REF="main"
export CPD_CONFIG_GIT_CONTEXT=""
```

- `CPD_CONFIG_GIT_REPO`: The clone URL of the GitHub repository that holds the configuration.
- `CPD_CONFIG_GIT_REF`: The branch, tag or commit ID to be cloned. If not specified, the repository's default branch will be cloned.
- `CPD_CONFIG_GIT_CONTEXT`: The directory within the GitHub repository that holds the configuration. This directory must contain the `config` directory under which the YAML files are kept.

!!! info
    When specifying a GitHub repository, the contents will be copied under `$STATUS_DIR/cpd-config` and this directory is then set as the configuration directory.    

## Optional: validate the configuration

If you only want to validate the configuration, you can run the dpeloyer with the `--check-only` argument. This will run the first stage to validate variables and vault secrets and then execute the generators.

```
./cp-deploy.sh env apply --check-only [--accept-all-licenses]
```

## Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply [--accept-all-licenses]
```

In the above commanYou can also specify extra variables such as `env_id` and `ibm_cloud_region` to override the names of the objects referenced in the `.yaml` configuration files as `{{ env_id }}-xxxx`. For more information about the extra (dynamic) variables, see [advanced configuration](../../../50-advanced/advanced-configuration).

The `--accept-all-licenses` flag is optional and confirms that you accept all licenses of the installed cartridges and instances. Licenses must be either accepted in the configuration files or at the command line.

When running the command, the container will start as a daemon and the command will tail-follow the logs. You can press Ctrl-C at any time to interrupt the logging but the container will continue to run in the background.

You can return to view the logs as follows:

```
./cp-deploy.sh env logs
```

Deploying the infrastructure, preparing OpenShift and installing the Cloud Pak will take a long time, typically between 1-5 hours,dependent on which Cloud Pak cartridges you configured. For estimated duration of the steps, refer to [Timings](../../../30-reference/timings).

If you need to interrupt the automation, use CTRL-C to stop the logging output and then use:

```
./cp-deploy.sh env kill
```

## On failure

If the Cloud Pak Deployer fails, for example because certain infrastructure components are temporarily not available, fix the cause if needed and then just re-run it with the same `CONFIG_DIR` and `STATUS_DIR` as well extra variables. The provisioning process has been designed to be idempotent and it will not redo actions that have already completed successfully.

## Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. You can also find this information under the `cloud-paks` directory in the status directory you specified.

To retrieve the Cloud Pak URL(s):

```
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd:
https://cpd-cpd.fke16h-a939e0e6a37f1ce85dbfddbb7ab97418-0000.eu-de.containers.appdomain.cloud
```

List the secrets in the vault:

```
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

You can then retrieve the Cloud Pak for Data admin password like this:

```
./cp-deploy.sh vault get --vault-secret cp4d_admin_zen_sample_sample
```

```output
PLAY [Secrets] *****************************************************************
included: /cloud-pak-deployer/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```

## Post-install configuration
You can find examples of a couple of typical changes you may want to do here: [Post-run changes](../../../10-use-deployer/5-post-run/post-run).