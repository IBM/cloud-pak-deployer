# Running the Cloud Pak Deployer on Microsoft Azure - ARO

## Topology

A typical setup of the ARO cluster is pictured below:
![ARO configuration](images/azure-aro.png)

The ARO cluster is deployed by using the Terraform in combination with the Azure Resource Manager (ARM) template.

When deploying ARO, you can configure the domain name by setting the `openshift.domain_name` attribute. The resulting domain name is managed by Azure, and it must be unique across all ARO instances deployed in Azure. Both the API and Ingress urls are set to be public in the template, so they can be resolved by external clients.

## Acquire an Red Hat OpenShift pull secret

To install OpenShift you need an OpenShift pull secret which holds your entitlement.

- Navigate and login to [Red Hat OpenShift cluster manager portal](https://cloud.redhat.com/openshift/install/azure/aro-provisioned)

- Click on `Download pull secret` button, and save the pull secret into the `/tmp/ocp_pullsecret.json` file.

## Acquire an IBM Cloud Pak Entitlement Key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

## Verify your permissions in Microsoft Azure

- Check [Azure resource quota](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#before-you-begin) of the subscription - Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster.
- The ARO cluster is provisioned using the `az` command. Ideally, one has to have `Contributor` permissions on the subscription (Azure resources) and `Application administrator` role assigned in the Azure Active Directory. See details [here](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#verify-your-permissions).

## Login to the Microsoft Azure

You are required to create a Service Principal and get Azure Red Hat OpenShift Resource Provider objectId before starting the deployment. The future steps expect that you are logged in to the Microsoft Azure by using CLI.

[Install Azure CLI tool](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=dnf), and run the commands in your operating system, or

Login to the Microsoft Azure:

- Azure Cloud CLI: `az login`
- If your tenant requires Multi-Factor Authentication (MFA), use: `az login --tenant <TENANT_ID>`
- If you have multiple Azure subscriptions, specify the relevant subscription ID: `az account set --subscription <SUBSCRIPTION_ID>`

You can list the subscriptions via command:
```bash
az account subscription list
```

```output
[
  {
    "authorizationSource": "RoleBased",
    "displayName": "IBM xxx",
    "id": "/subscriptions/dcexxx",
    "state": "Enabled",
    "subscriptionId": "dcexxx", ---> your_subscription_id parameter
    "subscriptionPolicies": {
      "locationPlacementId": "Public_2014-09-01",
      "quotaId": "EnterpriseAgreement_2014-09-01",
      "spendingLimit": "Off"
    }
  }
]
```

## Register Resource Providers

Make sure the following Resource Providers are registered for your subscription by running:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```


## Prepare for running

### Set environment variables for Azure ARO cluster

```
export CPD_AZURE-true
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

- `CPD_AZURE`: This environment variable ensures the that the `$HOME/.azure` directory is mapped into the deployer container
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

### Create the secrets needed for ARO

You need to store the OpenShift pull secret in the vault so that the deployer has access to it.

```
./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json
```

## Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply [--accept-all-licenses]
```

For more information about the extra (dynamic) variables, see [advanced configuration](../../../50-advanced/advanced-configuration).

The `--accept-all-licenses` flag is optional and confirms that you accept all licenses of the installed cartridges and instances. Licenses must be either accepted in the configuration files or at the command line.

When running the command, the container will start as a daemon and the command will tail-follow the logs. You can press Ctrl-C at any time to interrupt the logging but the container will continue to run in the background.

You can return to view the logs as follows:

```
./cp-deploy.sh env logs
```

Deploying the infrastructure, preparing OpenShift and installing the Cloud Pak will take a long time, typically between 1-5 hours, dependent on which Cloud Pak cartridges you configured. For estimated duration of the steps, refer to [Timings](../../../30-reference/timings).

If you need to interrupt the automation, use CTRL-C to stop the logging output and then use:

```
./cp-deploy.sh env kill
```

## Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. You can also find this information under the `cloud-paks` directory in the status directory you specified. The `admin` password can be retrieved from the vault as follows:

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
- cp4d_admin_zen_sample_sample
```

You can then retrieve the Cloud Pak for Data admin password like this:

```
./cp-deploy.sh vault get --vault-secret cp4d_admin_zen_sample_sample
```

```output
PLAY [Secrets] *****************************************************************
included: /automation_script/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```

## Post-install configuration
You can find examples of a couple of typical changes you may want to do here: [Post-run changes](../../../10-use-deployer/5-post-run/post-run).