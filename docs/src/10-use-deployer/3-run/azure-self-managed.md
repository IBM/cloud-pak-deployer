# Running the Cloud Pak Deployer on Microsoft Azure - Self-managed

## Topology

A typical setup of the OpenShift cluster on Azure is pictured below:
![Self-managed configuration](images/azure-aro.png)

When deploying self-managed OpenShift on Azure, you must configure the domain name by setting the `openshift.domain_name`, which must be public domain with a registrar. OpenShift will create a public DNS zone with additional entries to reach the OpenShift API and the applications (Cloud Paks). If you don't have a domain yet, you buy one from Azure: https://learn.microsoft.com/en-us/azure/app-service/manage-custom-dns-buy-domain.

## Acquire an Red Hat OpenShift pull secret

To install OpenShift you need an OpenShift pull secret which holds your entitlement.

When installing an IBM Cloud Pak, you can retrieve your Red Hat entitlement using instructions on this page: https://www.ibm.com/docs/en/cloud-paks/1.0?topic=iocpc-accessing-red-hat-entitlements-from-your-cloud-pak. Or, retrieve your pull secret from Red Hat: https://console.redhat.com/openshift/install/pull-secret.

Download the pull secret into file `/tmp/ocp_pullsecret.json`

## Acquire an IBM Cloud Pak Entitlement Key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

## Verify your quota and permissons in Microsoft Azure

- Check [Azure resource quota](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#before-you-begin) of the subscription - Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster.
- The ARO cluster is provisioned using the `az` command. Ideally, one has to have `Contributor` permissions on the subscription (Azure resources) and `Application administrator` role assigned in the Azure Active Directory. See details [here](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#verify-your-permissions).

## Login to the Microsoft Azure

You are required to create a Service Principal and get Azure Red Hat OpenShift Resource Provider objectId before starting the deployment. The future steps expect that you are logged in to the Microsoft Azure by using CLI.

[Install Azure CLI tool](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=dnf), and run the commands in your operating system, or

Login to the Microsoft Azure:
```
az login
```

If you have a subscription with multiple tenants, use:
```
az login --tenant <TENANT_ID>
```

Example:
```bash
az login --tenant 869930ac-17ee-4dda-bbad-7354c3e7629c8
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code AXWFQQ5FJ to authenticate.
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "869930ac-17ee-4dda-bbad-7354c3e7629c8",
    "id": "72281667-6d54-46cb-8423-792d7bcb1234",
    "isDefault": true,
    "managedByTenants": [],
    "name": "Azure Account",
    "state": "Enabled",
    "tenantId": "869930ac-17ee-4dda-bbad-7354c3e7629c8",
    "user": {
      "name": "you_user@domain.com",
      "type": "user"
    }
  }
]
```

### Set subscription (optional)

If you have multiple Azure subscriptions, specify the relevant subscription ID: `az account set --subscription <SUBSCRIPTION_ID>`

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

## Prepare Azure resources

### Set environment variables for Azure

```bash
export ENV_ID=env_id_in_config_files
export AZURE_SUBSCRIPTION_ID=your_azure_subscription_id
export AZURE_RESOURCE_GROUP=${ENV_ID}-rg
export AZURE_LOCATION=azure_location
export AZURE_SP=${ENV_ID}-sp
```

- `AZURE_SUBSCRIPTION_ID`: The id of your Azure subscription. Once logged in, you can retrieve this using the `az account show` command.
- `AZURE_RESOURCE_GROUP`: The Azure resource group that will hold all resources belonging to the cluster: VMs, load balancers, virtual networks, subnets, etc.. Typically you will create a resource group for every OpenShift cluster you provision.
- `AZURE_LOCATION`: The Azure location of the resource group, for example `useast` or `westeurope`.
- `AZURE_SP`: Azure service principal that is used to create the resources on Azure. Typically you will use a service principal for every OpenShift cluster you provision.

Example:
```bash
export ENV_ID=pluto-01
export AZURE_SUBSCRIPTION_ID=72281667-6d54-46cb-8423-792d7bcb1234
export AZURE_RESOURCE_GROUP=${ENV_ID}-rg
export AZURE_LOCATION=uksouth
export AZURE_SP=${ENV_ID}-sp
```

### Create resource group, service principal and set permissions

First the resource group must be created; this must be the same resource group as specified under `azure.resource_group.name` in the configuration file.
```bash
az group create \
  --name ${AZURE_RESOURCE_GROUP} \
  --location ${AZURE_LOCATION}
```

```output
{
  "id": "/subscriptions/72281667-6d54-46cb-8423-792d7bcb1234/resourceGroups/pluto-01-rg",
  "location": "uksouth",
  "managedBy": null,
  "name": "pluto-01-rg",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

Then, create the service principal that will do the installation and assign the `Contributor role`
```bash
az ad sp create-for-rbac \
  --role Contributor \
  --name ${AZURE_SP} \
  --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID} > /tmp/${AZURE_SP}-credentials.json
```

If you only have Contributor access to a resource group, you must specify the resource group scope instead:
```bash
az ad sp create-for-rbac \
  --role Contributor \
  --name ${AZURE_SP} \
  --scopes /subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/pluto-01-rg > /tmp/${AZURE_SP}-credentials.json
```

Example output in credentials file:
```output
{
  "appId": "a4c39ae9-f9d1-4038-b4a4-ab011e769111",
  "displayName": "pluto-01-sp",
  "password": "xyz-xyz",
  "tenant": "869930ac-17ee-4dda-bbad-7354c3e7629c8"
}
```

Finally, set the permissions of the service principal to allow creation of the OpenShift cluster
```bash
az role assignment create \
  --role "User Access Administrator" \
  --scope /subscriptions/${AZURE_SUBSCRIPTION_ID} \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id $(az ad sp list --display-name=${AZURE_SP} --query='[].id' -o tsv)
```

If you do not have permissions to list service principals, you can also run the following commands:
```bash
export AZURE_SP_ID=$(jq -r .appId /tmp/${AZURE_SP}-credentials.json)
az role assignment create \
  --role "User Access Administrator" \
  --scope /subscriptions/${AZURE_SUBSCRIPTION_ID} \
  --assignee-principal-type ServicePrincipal \
  --assignee-object-id $(az ad sp show --id ${AZURE_SP_ID} --query='id' -o tsv)
```

## Prepare for running

### Set environment variables for deployer

```
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

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

### Create the secrets needed for Azure deployment

You need to store the below secrets in the vault so that the deployer has access to them when installing self-managed OpenShift cluster on Azure.

```
./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json

./cp-deploy.sh vault set \
    --vault-secret ${AZURE_SP}-credentials \
    --vault-secret-file /tmp/${AZURE_SP}-credentials.json

# Optional if you would like to use your own public key
./cp-deploy.sh vault set \
    --vault-secret ocp-ssh-pub-key \
    --vault-secret-file ~/.ssh/id_rsa.pub
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