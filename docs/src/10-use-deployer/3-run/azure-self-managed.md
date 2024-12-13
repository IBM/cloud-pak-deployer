# Running the Cloud Pak Deployer on Microsoft Azure - Self-managed

On Azure, OpenShift can be set up in various ways, managed by Red Hat (ARO) or self-managed. The steps below are applicable to the self-managed Red Hat OpenShift.

There are 5 main steps to run the deployer for Azure:

1. [Configure deployer](#1-configure-deployer)
2. [Prepare the cloud environment](#2-prepare-the-cloud-environment)
3. [Obtain entitlement keys and secrets](#3-acquire-entitlement-keys-and-secrets)
4. [Set environment variables and secrets](#4-set-environment-variables-and-secrets)
5. [Run the deployer](#5-run-the-deployer)
6. [Post-install configuration (Add GPU nodes)](#6-post-install-configuration)

## Topology

A typical setup of the OpenShift cluster on Azure is pictured below:
![Self-managed configuration](images/azure-aro.png)

### Public self-managed OpenShift
When deploying a public self-managed OpenShift on Azure, the `openshift.domain_name` domain name must be registered with a registrar. OpenShift will create a public DNS zone with additional entries to reach the OpenShift API and the applications (Cloud Paks). If you don't have a domain yet, you buy one from Azure: https://learn.microsoft.com/en-us/azure/app-service/manage-custom-dns-buy-domain.

### Private self-managed OpenShift
When deploying a self-managed OpenShift in a private network on Azure, the `openshift.domain_name` references the private DNS zone that is created within the resource group that also holds the OpenShift control plane VMs, compute VMs and many other resources. For a private deployment, the virtual network (vnet) must exist already in a different resource group and it must have subnets for the control plane and compute plane. 

!!! info
To ensure that the deployer can do a lookup of the OpenShift API server, it is easiest to run it on a server in the same existing vnet. If the OpenShift installer cannot contact the API server during the installation, it will fail and so will the deployer.

## 1. Configure deployer

### Deployer configuration and status directories
Deployer reads the configuration from a directory you set in the `CONFIG_DIR` environment variable. A status directory (`STATUS_DIR` environment variable) is used to log activities, store temporary files, scripts. If you use a File Vault (default), the secrets are kept in the `$STATUS_DIR/vault` directory.

You can find OpenShift and Cloud Pak sample configuration (yaml) files here: [sample configuration](https://github.com/IBM/cloud-pak-deployer/tree/main/sample-configurations/sample-dynamic/config-samples). For Azure self-managed installations, copy one of `ocp-azure-self-managed*.yaml` files into the `$CONFIG_DIR/config` directory. If you also want to install a Cloud Pak, copy one of the `cp4*.yaml` files.

Example:
``` { .bash .copy }
mkdir -p $HOME/cpd-config/config
cp sample-configurations/sample-dynamic/config-samples/ocp-azure-self-managed.yaml $HOME/cpd-config/config/
cp sample-configurations/sample-dynamic/config-samples/cp4d-471.yaml $HOME/cpd-config/config/
```

### Set configuration and status directories environment variables
Cloud Pak Deployer uses the status directory to log its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. 

``` { .bash .copy }
export CONFIG_DIR=$HOME/cpd-config
export STATUS_DIR=$HOME/cpd-status
```

- `CONFIG_DIR`: Directory that holds the configuration, it must have a `config` subdirectory which contains the configuration `yaml` files.
- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files.

#### Optional: advanced configuration
If the deployer configuration is kept on GitHub, follow the instructions in [GitHub configuration](../../50-advanced/advanced-configuration.md#using-a-github-repository-for-the-configuration).

For special configuration with defaults and dynamic variables, refer to [Advanced configuration](../../50-advanced/advanced-configuration.md#using-dynamic-variables-extra-variables).

## 2. Prepare the cloud environment

### Install the Azure CLI tool

[Install Azure CLI tool](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=dnf), and run the commands in your operating system.

### Verify your quota and permissions in Microsoft Azure

- Check [Azure resource quota](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#before-you-begin) of the subscription - Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster.
- The self-managed cluster is provisioned using the IPI installer command. Ideally, one has to have `Contributor` permissions on the subscription (Azure resources) and `Application administrator` role assigned in the Azure Active Directory. See details [here](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#verify-your-permissions).

### Set environment variables for Azure

``` { .bash .copy }
export AZURE_RESOURCE_GROUP=pluto-01-rg
export AZURE_LOCATION=westeurope
export AZURE_SP=pluto-01-sp
```

- `AZURE_RESOURCE_GROUP`: The Azure resource group that will hold all resources belonging to the cluster: VMs, load balancers, virtual networks, subnets, etc.. Typically you will create a resource group for every OpenShift cluster you provision.
- `AZURE_LOCATION`: The Azure location of the resource group, for example `useast` or `westeurope`.
- `AZURE_SP`: Azure service principal that is used to create the resources on Azure. You will get the service principal from the Azure administrator.

### Create or check existence of the virtual network for private OpenShift installations

If you install OpenShift with private endpoints, the vnet must already exist in a different resource gruop from the `$AZURE_RESOURCE_GROUP`. For convenience, this resource group is referred to as the `AZURE_NETWORK_RESOURCE_GROUP`. Plese check the following:

- The vnet exists and is in the same `AZURE_LOCATION` as the OpenShift cluster
- The vnet has 2 subnets, one for the control plane VMs and one for the compute VMs
- The service principal has `Contributor` and `User Access Administrator` permissions on the `AZURE_NETWORK_RESOURCE_GROUP` that holds the vnet. Check the instructions to [create the role assignments](./azure-service-principal.md#set-permissions-for-additional-resource-groups)

### Create the resource group (if not already done)

First the resource group must be created; this resource group must match the one configured in your OpenShift yaml config file. Create the resource group if this was not already done by the Azure administrator.
``` { .bash .copy }
az group create \
  --name ${AZURE_RESOURCE_GROUP} \
  --location ${AZURE_LOCATION}
```

### Store Service Principal credentials

You must run the OpenShift installation using an Azure Service Principal with sufficient permissions. The Azure account administrator will share the SP credentials as a JSON file. If you have subscription-level access you can also create the Service Principal yourself. See steps in [Create Azure service principal](./azure-service-principal.md).

Example output in credentials file:
```output
{
  "appId": "a4c39ae9-f9d1-4038-b4a4-ab011e769111",
  "displayName": "pluto-01-sp",
  "password": "xyz-xyz",
  "tenant": "869930ac-17ee-4dda-bbad-7354c3e7629c8"
}
```

Store this file as `/tmp/${AZURE_SP}-credentials.json`.

## 3. Acquire entitlement keys and secrets

### Acquire IBM Cloud Pak entitlement key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

### Acquire an OpenShift pull secret

To install OpenShift you need an OpenShift pull secret which holds your entitlement.

- Navigate to https://console.redhat.com/openshift/install/pull-secret and download the pull secret into file `/tmp/ocp_pullsecret.json`

### Optional: Locate or generate a public SSH Key
To obtain access to the OpenShift nodes post-installation, you will need to specify the public SSH key of your server; typically this is `~/.ssh/id_rsa.pub`, where `~` is the home directory of your user. If you don't have an SSH key-pair yet, you can generate one using the steps documented here: https://cloud.ibm.com/docs/ssh-keys?topic=ssh-keys-generating-and-using-ssh-keys-for-remote-host-authentication#generating-ssh-keys-on-linux. Alternatively, deployer can generate SSH key-pair automatically if credential `ocp-ssh-pub-key` is not in the vault.

## 4. Set environment variables and secrets

### Set the Cloud Pak entitlement key
If you want the Cloud Pak images to be pulled from the entitled registry, set the Cloud Pak entitlement key.

``` { .bash .copy }
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string. **You don't need to set this environment variable when you install the Cloud Pak(s) from a private registry**

### Create the secrets needed for self-managed OpenShift cluster

You need to store the OpenShift pull secret and service principal credentials in the vault so that the deployer has access to it.

``` { .bash .copy }
./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json


./cp-deploy.sh vault set \
    --vault-secret ${AZURE_SP}-credentials \
    --vault-secret-file /tmp/${AZURE_SP}-credentials.json
```

### Optional: Create secret for public SSH key

If you want to use your SSH key to access nodes in the cluster, set the Vault secret with the public SSH key.
``` { .bash .copy }
./cp-deploy.sh vault set \
    --vault-secret ocp-ssh-pub-key \
    --vault-secret-file ~/.ssh/id_rsa.pub
```

### Optional: Set the GitHub Personal Access Token (PAT)
In some cases, download of the `cloudctl` and `cpd-cli` clients from https://github.com/IBM will fail because GitHub limits the number of API calls from non-authenticated clients. You can remediate this issue by creating a [Personal Access Token on github.com](https://github.com/settings/tokens) and creating a secret in the vault.

``` { .bash .copy }
./cp-deploy.sh vault set -vs github-ibm-pat=<your PAT>
```

Alternatively, you can set the secret by adding `-vs github-ibm-pat=<your PAT>` to the `./cp-deploy.sh env apply` command.

## 5. Run the deployer

### Optional: validate the configuration

If you only want to validate the configuration, you can run the dpeloyer with the `--check-only` argument. This will run the first stage to validate variables and vault secrets and then execute the generators.

``` { .bash .copy }
./cp-deploy.sh env apply --check-only --accept-all-licenses
```

### Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

``` { .bash .copy }
./cp-deploy.sh env apply --accept-all-licenses
```

You can also specify extra variables such as `env_id` to override the names of the objects referenced in the `.yaml` configuration files as `{{ env_id }}-xxxx`. For more information about the extra (dynamic) variables, see [advanced configuration](../../../50-advanced/advanced-configuration).

The `--accept-all-licenses` flag is optional and confirms that you accept all licenses of the installed cartridges and instances. Licenses must be either accepted in the configuration files or at the command line.

When running the command, the container will start as a daemon and the command will tail-follow the logs. You can press Ctrl-C at any time to interrupt the logging but the container will continue to run in the background.

You can return to view the logs as follows:

``` { .bash .copy }
./cp-deploy.sh env logs
```

Deploying the infrastructure, preparing OpenShift and installing the Cloud Pak will take a long time, typically between 1-5 hours,dependent on which Cloud Pak cartridges you configured. For estimated duration of the steps, refer to [Timings](../../../30-reference/timings).

If you need to interrupt the automation, use CTRL-C to stop the logging output and then use:

``` { .bash .copy }
./cp-deploy.sh env kill
```

### On failure

If the Cloud Pak Deployer fails, for example because certain infrastructure components are temporarily not available, fix the cause if needed and then just re-run it with the same `CONFIG_DIR` and `STATUS_DIR` as well extra variables. The provisioning process has been designed to be idempotent and it will not redo actions that have already completed successfully.

### Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. You can also find this information under the `cloud-paks` directory in the status directory you specified.

To retrieve the Cloud Pak URL(s):

``` { .bash .copy }
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd (domain name specified was example.com):
https://cpd-cpd.apps.pluto-01.example.com
```

The `admin` password can be retrieved from the vault as follows:

List the secrets in the vault:

``` { .bash .copy }
./cp-deploy.sh vault list
```

This will show something similar to the following:

```output
Secret list for group sample:
- ibm_cp_entitlement_key
- sample-provision-ssh-key
- sample-provision-ssh-pub-key
- cp4d_admin_cpd_demo
```

You can then retrieve the Cloud Pak for Data admin password like this:

``` { .bash .copy }
./cp-deploy.sh vault get --vault-secret cp4d_admin_zen_sample_sample
```

```output
PLAY [Secrets] *****************************************************************
included: /automation_script/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```

## 6. Post-install configuration
You can find examples of a couple of typical changes you may want to do here: [Post-run changes](../../../10-use-deployer/5-post-run/post-run):

* Update the Cloud Pak for Data administrator password
* Add GPU node(s) to your OpenShift cluster