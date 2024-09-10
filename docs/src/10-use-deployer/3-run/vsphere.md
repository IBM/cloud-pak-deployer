# Running the Cloud Pak Deployer on vSphere

You can use Cloud Pak Deployer to create an OpenShift cluster on VMWare infrastructure.

There are 5 main steps to run the deployer for vSphere:

1. [Configure deployer](#1-configure-deployer)
2. [Prepare the cloud environment](#2-prepare-the-cloud-environment)
3. [Obtain entitlement keys and secrets](#3-acquire-entitlement-keys-and-secrets)
4. [Set environment variables and secrets](#4-set-environment-variables-and-secrets)
5. [Run the deployer](#5-run-the-deployer)

## Topology

A typical setup of the vSphere cluster with OpenShift is pictured below:
![vSphere configuration](images/vsphere-ocs-nfs.png)

When deploying OpenShift and the Cloud Pak(s) on VMWare vSphere, there is a dependency on a DHCP server for issuing IP addresses to the newly configured cluster nodes. Also, once the OpenShift cluster has been installed, valid fully qualified host names are required to connect to the OpenShift API server at port `6443` and applications running behind the ingress server at port `443`. The Cloud Pak deployer cannot set up a DHCP server or a DNS server and to be able to connect to OpenShift or to reach the Cloud Pak after installation, name entries must be set up.

## 1. Configure deployer

### Deployer configuration and status directories
Deployer reads the configuration from a directory you set in the `CONFIG_DIR` environment variable. A status directory (`STATUS_DIR` environment variable) is used to log activities, store temporary files, scripts. If you use a File Vault (default), the secrets are kept in the `$STATUS_DIR/vault` directory.

You can find OpenShift and Cloud Pak sample configuration (yaml) files here: [sample configuration](https://github.com/IBM/cloud-pak-deployer/tree/main/sample-configurations/sample-dynamic/config-samples). For vSphere installations, copy one of `ocp-vsphere-*.yaml` files into the `$CONFIG_DIR/config` directory. If you also want to install a Cloud Pak, copy one of the `cp4*.yaml` files.

Example:
```
mkdir -p $HOME/cpd-config/config
cp sample-configurations/sample-dynamic/config-samples/ocp-vsphere-ocs-nfs.yaml $HOME/cpd-config/config/
cp sample-configurations/sample-dynamic/config-samples/cp4d-471.yaml $HOME/cpd-config/config/
```

### Set configuration and status directories environment variables
Cloud Pak Deployer uses the status directory to log its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. 

```
export CONFIG_DIR=$HOME/cpd-config
export STATUS_DIR=$HOME/cpd-status
```

- `CONFIG_DIR`: Directory that holds the configuration, it must have a `config` subdirectory which contains the configuration `yaml` files.
- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files.

#### Optional: advanced configuration
If the deployer configuration is kept on GitHub, follow the instructions in [GitHub configuration](../../50-advanced/advanced-configuration.md#using-a-github-repository-for-the-configuration).

For special configuration with defaults and dynamic variables, refer to [Advanced configuration](../../50-advanced/advanced-configuration.md#using-dynamic-variables-extra-variables).

## 2. Prepare the cloud environment

### Pre-requisites for vSphere
In order to successfully install OpenShift on vSphere infrastructure, the following pre-requisites must have been met.

| Pre-requisite       | Description 
| ------------------- | ------------
| Red Hat pull secret | A pull secret is required to download and install OpenShift. See [Acquire pull secret](#acquire-an-openshift-pull-secret)
| IBM Entitlement key | When instaling an IBM Cloud Pak, you need an IBM entitlement key. See [Acquire IBM Cloud Pak entitlement key](#acquire-an-ibm-cloud-pak-entitlement-key)
| vSphere credentials | The OpenShift IPI installer requires vSphere credentials to create VMs and storage
| Firewall rules      | The OpenShift cluster's API server on port 6443 and application server on port 443 must be reachable.
| Whitelisted URLs    | The OpenShift and Cloud Pak download locations and registry must be accessible from the vSphere infrastructure. See [Whitelisted locations](../../../50-advanced/locations-to-whitelist)
| DHCP                | When provisioning new VMs, IP addresses must be automatically assigned through DHCP 
| DNS                 | A DNS server that will resolve the OpenShift API server and applications is required. See [DNS configuration](#dns-configuration) 
| Time server         | A time server to synchronize the time must be available in the network and configured through the DHCP server 


There are also some optional settings, dependent on the specifics of the installation:

| Pre-requisite       | Description 
| ------------------- | ------------ 
| Bastion server      | It can be useful to have a bastion/installation server to run the deployer. This (virtual) server must reside within the vSphere network 
| NFS details         | If an NFS server is used for storage, it must be reacheable (firewall) and `no_root_squash` must be set 
| Private registry    | If the installation must use a private registry for the Cloud Pak installation, it must be available and credentials shared 
| Certificates        | If the Cloud Pak URL must have a CA-signed certificate, the key, certificate and CA bundle must be available at instlalation time
| Load balancer       | The OpenShift IPI install creates 2 VIPs and takes care of the routing to the services. In some implementations, a load balancer provided by the infrastructure team is preferred. This load balancer must be configured externally

### DNS configuration

During the provisioning and configuration process, the deployer needs access to the OpenShift API and the ingress server for which the IP addresses are specified in the `openshift` object.

Ensure that the DNS server has the following entries:

- `api.openshift_name.domain_name` --> Point to the `api_vip` address configured in the `openshift` object
- `*.apps.openshift_name.domain_name` --> Point to the `ingress_vip` address configured in the `openshift` object

If you do not configure the DNS entries upfront, the deployer will still run and it will "spoof" the required entries in the container's `/etc/hosts` file. However to be able to connect to OpenShift and access the Cloud Pak, the DNS entries are required.

### Obtain the vSphere user and password

In order for the Cloud Pak Deployer to create the infrastructure and deploy the IBM Cloud Pak, it must have provisioning access to vSphere and it needs the vSphere user and password. The user must have permissions to create virtual machines.

### Set environment variables for vSphere

```
export VSPHERE_USER=your_vsphere_user
export VSPHERE_PASSWORD=password_of_the_vsphere_user
```

- `VSPHERE_USER`: This is the user name of the vSphere user, often this is something like `admin@vsphere.local`
- `VSPHERE_PASSWORD`: The password of the vSphere user. Be careful with special characters like `$`, `!` as they are not accepted by the IPI provisioning of OpenShift

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

```
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string. **You don't need to set this environment variable when you install the Cloud Pak(s) from a private registry**

### Create the secrets needed for vSphere deployment

You need to store the OpenShift pull secret in the vault so that the deployer has access to it.

```
./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json
```

### Optional: Create secret for public SSH key
If you want to use your SSH key to access nodes in the cluster, set the Vault secret with the public SSH key.
```
./cp-deploy.sh vault set \
    --vault-secret ocp-ssh-pub-key \
    --vault-secret-file ~/.ssh/id_rsa.pub
```

### Optional: Set the GitHub Personal Access Token (PAT)
In some cases, download of the `cloudctl` and `cpd-cli` clients from https://github.com/IBM will fail because GitHub limits the number of API calls from non-authenticated clients. You can remediate this issue by creating a [Personal Access Token on github.com](https://github.com/settings/tokens) and creating a secret in the vault.

```
./cp-deploy.sh vault set -vs github-ibm-pat=<your PAT>
```

Alternatively, you can set the secret by adding `-vs github-ibm-pat=<your PAT>` to the `./cp-deploy.sh env apply` command.

## 5. Run the deployer

### Optional: validate the configuration

If you only want to validate the configuration, you can run the dpeloyer with the `--check-only` argument. This will run the first stage to validate variables and vault secrets and then execute the generators.

```
./cp-deploy.sh env apply --check-only --accept-all-licenses
```

### Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply --accept-all-licenses
```

You can also specify extra variables such as `env_id` to override the names of the objects referenced in the `.yaml` configuration files as `{{ env_id }}-xxxx`. For more information about the extra (dynamic) variables, see [advanced configuration](../../../50-advanced/advanced-configuration).

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

### On failure

If the Cloud Pak Deployer fails, for example because certain infrastructure components are temporarily not available, fix the cause if needed and then just re-run it with the same `CONFIG_DIR` and `STATUS_DIR` as well extra variables. The provisioning process has been designed to be idempotent and it will not redo actions that have already completed successfully.

### Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. You can also find this information under the `cloud-paks` directory in the status directory you specified.

To retrieve the Cloud Pak URL(s):

```
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd (domain name specified was example.com):
https://cpd-cpd.apps.pluto-01.example.com
```

The `admin` password can be retrieved from the vault as follows:

List the secrets in the vault:

```
./cp-deploy.sh vault list
```

This will show something similar to the following:

```output
Secret list for group sample:
- vsphere-user
- vsphere-password
- ocp-pullsecret
- ocp-ssh-pub-key
- ibm_cp_entitlement_key
- sample-kubeadmin-password
- cp4d_admin_cpd_demo
```

You can then retrieve the Cloud Pak for Data admin password like this:

```
./cp-deploy.sh vault get --vault-secret cp4d_admin_cpd_demo
```

```output
PLAY [Secrets] *****************************************************************
included: /cloud-pak-deployer/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```

### Post-install configuration
You can find examples of a couple of typical changes you may want to do here: [Post-run changes](../../../10-use-deployer/5-post-run/post-run).