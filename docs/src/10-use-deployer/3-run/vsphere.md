# Running the Cloud Pak Deployer on vSphere

## Topology

A typical setup of the vSphere cluster with OpenShift is pictured below:
![vSphere configuration](images/vsphere-ocs-nfs.png)

When deploying OpenShift and the Cloud Pak(s) on VMWare vSphere, there is a dependency on a DHCP server for issuing IP addresses to the newly configured cluster nodes. Also, once the OpenShift cluster has been installed, valid fully qualified host names are required to connect to the OpenShift API server at port `6443` and applications running behind the ingress server at port `443`. The Cloud Pak deployer cannot set up a DHCP server or a DNS server and to be able to connect to OpenShift or to reach the Cloud Pak after installation, name entries must be set up.

### DNS configuration

Ensure that the DNS server has the following entries:

- `api.openshift_name.domain_name` --> Point to the `api_vip` address configured in the `openshift` object
- `*.apps.openshift_name.domain_name` --> Point to the `ingress_vip` address configured in the `openshift` object

If you do not configure the DNS entries upfront, the deployer will still run and it will "spoof" the required entries in the container's `/etc/hosts` file. However to be able to connect to OpenShift and access the Cloud Pak, the DNS entries are required.

## Obtain the vSphere user and password

In order for the Cloud Pak Deployer to create the infrastructure and deploy the IBM Cloud Pak, it must have provisioning access to vSphere and it needs the vSphere user and password. The user must have permissions to create VM folders and virtual machines.

## Acquire an OpenShift pull secret

To install OpenShift you need an OpenShift pull secret which holds your entitlement.

- Navigate to https://console.redhat.com/openshift/install/pull-secret and download the pull secret into file `/tmp/ocp_pullsecret.json`

## Acquire an IBM Cloud Pak Entitlement Key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

## Optional: Locate or generate a public SSH Key
To obtain access to the OpenShift nodes post-installation, you will need to specify the public SSH key of your server; typically this is `~/.ssh/id_rsa.pub`, where `~` is the home directory of your user. If you don't have an SSH key-pair yet, you can generate one using the steps documented here: https://docs.openshift.com/container-platform/4.10/installing/installing_aws/installing-aws-customizations.html#ssh-agent-using_installing-aws-customizations. Alternatively, deployer can generate SSH key-pair automatically if credential `ocp-ssh-pub-key` is not in the vault.

## Prepare for running

### Set environment variables

```
export VSPHERE_USER=your_vsphere_user
export VSPHERE_PASSWORD=password_of_the_vsphere_user
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

Optional: Ensure that the environment variables for the configuration and status directories are set. If not specified, the directories are assumed to be `$HOME/cpd-config` and `$HOME/cpd-status`.
```
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `VSPHERE_USER`: This is the user name of the vSphere user, often this is something like `admin@vsphere.local`
- `VSPHERE_PASSWORD`: The password of the vSphere user. Be careful with special characters like `$`, `!` as they are not accepted by the IPI provisioning of OpenShift
- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string
- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files. **Please note** that if you have chosen to use a File Vault, the properties file is keps under the `vault` directory within the status directory
- `CONFIG_DIR`: Directory that holds the configuration, it must have `config`, `defaults` and `inventory` subdirectories

!!! info
    Cloud Pak Deployer uses the status directory to logs its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. You can run the Cloud Pak Deployer in parallel for different environments (different configuration directories).

### Create the secrets needed for vSphere

You need to store the vSphere user and password in the vault so that the deployer has access to them when doing the IPI install.

```
./cp-deploy.sh vault set \
    --vault-secret vsphere-user \
    --vault-secret-value $VSPHERE_USER

./cp-deploy.sh vault set \
    --vault-secret vsphere-password \
    --vault-secret-value $VSPHERE_PASSWORD

./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json

# Optional when you would like to use the public key which is generated by deployer
./cp-deploy.sh vault set \
    --vault-secret ocp-ssh-pub-key \
    --vault-secret-file ~/.ssh/id_rsa.pub
```

## Optional: validate the configuration

If you only want to validate the configuration, you can run the dpeloyer with the `--check-only` argument. This will run the first stage to validate variables and vault secrets and then execute the generators.

```
./cp-deploy.sh env apply --check-only [--accept-all-liceneses]
```

## Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply [--accept-all-liceneses]
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

## DNS entries needed for vSphere provisioning

During the provisioning and configuration process, the deployer needs access to the OpenShift API server and the ingress server. These have been specified in the `openshift` object. To avoid any dependencies on the DNS entries for these servers to be present prior to provisioning, the deployer will add `api.<cluster + domain name>` and several <.apps.<cluster + domain name>`entries to the`/etc/hosts` file within the container. Once the deployer has completed, but ideally even before, you must add the appropriate entries to our DNS server:

\*.apps.<cluster + domain name> must be mapped to the `ingress_vip` address
api.<cluster + domain name> must be mapped to the `api_vip` address

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