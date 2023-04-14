# Running the Cloud Pak Deployer on Microsoft Azure - ARO

## Topology

A typical setup of the ARO cluster is pictured below:
![ARO configuration](images/azure-aro.png)

The ARO cluster is deployed by using the Terraform in combination with the Azure Resource Manager (ARM) template.

When deploying ARO, you can partially configure the domain name by setting the `openshift.subdomain_name` attribute. The resulting domain name is managed by Azure, and it must be unique across all ARO instances deployed in Azure. Both the API and Ingress urls are set to be public in the template, so they can be resolved by external clients.

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
- The ARO cluster is provisioned by using ARM template which expects Service Principal to be created and used. Ideally, one has to have `Contributor` permissions on the subscription (Azure resources) and `Application administrator` role assigned in the Azure Active Directory. See details [here](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#verify-your-permissions).

## Login to the Microsoft Azure

You are required to create a Service Principal and get Azure Red Hat OpenShift Resource Provider objectId before starting the deployment. The future steps expect that you are logged in to the Microsoft Azure by using CLI. You can either:

- [Install Azure CLI tool](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/azure-get-started#install-terraform), and run the commands in your operationg system, or
- use the Azure CLI tool which is already installed in the deployer image. You need to run the container with the overridden entrypoint, and thus get the interactive access to the tools inside ([`docker` | `podman`]), i.e: `docker run -it --name cpd-cli --entrypoint /bin/bash cloud-pak-deployer:latest`

Login to the Microsoft Azure:

- Azure Cloud CLI: `az login`
- If your tenant requires Multi-Factor Authentication (MFA), use: `az login --tenant <TENANT_ID>`
- If you have multiple Azure subscriptions, specify the relevant subscription ID: `az account set --subscription <SUBSCRIPTION_ID>`

## Register Resource Providers

Make sure the following Resource Providers are registered for your subscription by running:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

## Create a Service Principal

```bash
# Specify a name for your service principal, e.g. cpd-sp
export SPNAME=cpd-sp

# Create your service principal
az ad sp create-for-rbac --name $SPNAME
# {
#   "appId": "694bxxx",          ---> service_principal_id parameter
#   "displayName": "$SPNAME",
#   "name": "694xxx",
#   "password": "CXxxx",         ---> service_principal_secret parameter
#   "tenant": "bb0xxx"
# }

# Get objectId of your service principal
az ad sp list --filter "displayname eq '$SPNAME'" --query "[?appDisplayName=='$SPNAME'].{name: appDisplayName, objectId: objectId}"
# [
#   {
#     "name": "$SPNAME",
#     "objectId": "70bdxxx"      ---> service_principal_object_id parameter
#   }
# ]
```

You may want to create the service principal with the `Contributor` role by adding `--role="Contributor"` (the first command above). Anyhow, in the ARM template, the Contributor role is assigned to the given service principal (Virtual Network scope).

!!! info
    Pay attention to the "service_principal_id", "service_principal_secret", and "service_principal_object_id" output parameter notes. They will be used later.

## Get Azure Red Hat OpenShift Resource Provider objectId

The ARM template also needs to grant the ARO 4 Resource Provider service principal permissions in order to provision and manage clusters. To obtain the ARO 4 RP service principal object id execute the following command:

```bash
az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'" --query "[?appDisplayName=='Azure Red Hat OpenShift RP'].{name: appDisplayName, objectId: objectId}"
# [
#   {
#     "name": "Azure Red Hat OpenShift RP",
#     "objectId": "28exxx"       ---> aro_rp_object_id parameter
#   }
# ]
```

!!! info
    Pay attention to the "aro_rp_object_id" output parameter note. This will be used later.

## Prepare for running

### Set environment variables

```
export ARO_TENANT_ID=your_tenant_id
export ARO_SUBSCRIPTION_ID=your_subscription_id
export ARO_SP_ID=service_principal_id_created_above
export ARO_SP_SECRET=service_principal_secret_created_above
export ARO_SP_OBJECT_ID=service_principal_object_id_created_above
export ARO_RP_OBJECT_ID=aro_rp_object_id_obtained_above

export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

Optional: Ensure that the environment variables for the configuration and status directories are set. If not specified, the directories are assumed to be `$HOME/cpd-config` and `$HOME/cpd-status`.

```
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `ARO_TENANT_ID`: Azure Active Directory tenant id.
- `ARO_SUBSCRIPTION_ID`: Subscription id (agreement) with Microsoft to use one or more Microsoft cloud platforms or services. An organization can have multiple subscriptions that use the same Azure AD tenant.
- `ARO_SP_ID`: Service Principal id (appId) which is used to login to Microsoft Azure by the terraform process. At the same time, the ARM template uses the same Service Principal to deploy the cluster.
- `ARO_SP_SECRET`: Secret password of the Service Principal
- `ARO_SP_OBJECT_ID`: Object id of the Service Principal
- `ARO_RP_OBJECT_ID`: Object id of the Azure Red Hat OpenShift Resource Provider
- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string
- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files. **Please note** that if you have chosen to use a File Vault, the properties file is keps under the `vault` directory within the status directory
- `CONFIG_DIR`: Directory that holds the configuration, it must have `config` and optionally `defaults` and `inventory` subdirectories

!!! info
    Cloud Pak Deployer uses the status directory to logs its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. You can run the Cloud Pak Deployer in parallel for different environments (different configuration directories).

### Create the secrets needed for ARO

You need to store all `ARO_` environments variables together with the OpenShift pull secret in the vault so that the deployer has access to them.

```
./cp-deploy.sh vault set \
    --vault-secret aro-tenant-id \
    --vault-secret-value $ARO_TENANT_ID

./cp-deploy.sh vault set \
    --vault-secret aro-subscription-id \
    --vault-secret-value $ARO_SUBSCRIPTION_ID

./cp-deploy.sh vault set \
    --vault-secret aro-sp-id \
    --vault-secret-value $ARO_SP_ID

./cp-deploy.sh vault set \
    --vault-secret aro-sp-secret \
    --vault-secret-value $ARO_SP_SECRET

./cp-deploy.sh vault set \
    --vault-secret aro-sp-object-id \
    --vault-secret-value $ARO_SP_OBJECT_ID

./cp-deploy.sh vault set \
    --vault-secret aro-rp-object-id \
    --vault-secret-value $ARO_RP_OBJECT_ID

./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json
```

## Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply -e azure_location=westeurope [--accept-all-licenses]
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
- sample-terraform-tfstate
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