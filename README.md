# Cloud Pak Deployer

![Provisioner pipeline](/images/Provisioner-pipeline.png)

## Installing the Cloud Pak Deployer

### Install pre-requisites
Start with a server running a linux OS, like Red Hat or CentOS
```
yum install -y podman git
yum clean all
```

### Optional - Install EPEL and screen
If you want to run the deployer in a screen session, you also need to install EPEL and the screen package.
```
yum install -y epel-release && \
yum install -y screen
```

### Clone the current repository
```
# TODO: specify eventual location of the Cloud Pak Deployer
git clone ...
```

### Build the image
The container image must be built from the directory that holds the `Dockerfile` file.
```
cd cloud-pak-deployer
podman build -t cloud-pak-deployer .
```

This process will take 2-10 minutes to complete and it will install all the pre-requisites needed to run the automation, including Ansible, Terraform and operating system packages. For the installation to work, the system on which the image is built must be connected to the internet.

## Using the Cloud Pak Deployer

### Create an IBM Cloud API Key
In order for the Cloud Pak Deplyer to create the infrastructure and deploy IBM Cloud Pak for Data, it must perform tasks on IBM Cloud. In order to do so it requires an IBM Cloud API Key. This can be created by following these steps:
- Log on to IBM Cloud on https://cloud.ibm.com/login and login with your IBMId credentials
- Ensure you have selected the correct IBM Cloud Account for which you wish to use the Cloud Pak Deployer
- Navigate to Manage --> Access (IAM)
- Select Api Keys
- Click **Create an IBM Cloud API Key** and provide a name and description
- Copy the IBM Cloud API key and store it, as you will not be able to retrieve it later

### Create a Container Registry namespace
During the Deployment of Cloud Pak for Data, the images will be transferred from the IBM Container Registry to your own Container Registry Namespace.
- Log on to IBM Cloud on https://cloud.ibm.com/login and login with your IBMId credentials
- Ensure you have selected the correct IBM Cloud Account for which you wish to use the Cloud Pak Deployer
- Using the Hamburger menu button, nagivate to OpenShift --> Registry
- Select Namespaces
- Click Create and provide the name for the Container Registry namespace
After the Container Registry namespace is created, ensure you have sufficient quota to store the images
- Click Settings
- Make sure the Storage Quota has 200Gb available and the Pull traffic is set to unlimited or has sufficient quota 

### Acquire an IBM Cloud Pak for Data Entitlement Key
For the Cloud Pak Deployer to access the IBM Cloud Pak for Data source images, an entitlement key is required:
- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value and store it

### Create your configuration
The Cloud Pak Deployer requires the desired end-state to be configured in a pre-defined directory structure. This structure may exist on the server that runs the utility or can be pulled from a (branch of a) Git repository. 

#### Create configuration directory structure
Use the following directory structure; you can copy a template from the `./sample` directory in included in this repository.
```
CONFIG_DIR  --> /config
                - cpd.yaml
            --> /inventory
                - cpd.inv
            --> /generator_config (do not make any changes in this folder)
```
Adjust the /config/cpd.yaml and /inventory/cpd.inv to set the desired end-state of the deployment. 

### Run the deployment
To run cloud-pak-deployer container, a cp-deploy command is available. Run ./cp-deploy.sh help to display the help

```
 ./cp-deploy.sh

Usage: ./cp-deploy.sh SUBCOMMAND ACTION [OPTIONS]

SUBCOMMAND:
  environment,env           Apply configuration to create, modify or destroy an environment
  vault                     Get, create, modify or delete secrets in the configured vault
  help,h                    Show help

ACTION:
  environment:
    apply                   Create a new or modify an existing environment
    destroy                 Destroy an existing environment
  vault:
    get                     Get a secret from the vault and return its value
    set                     Create or update a secret in the vault
    delete                  Delete a secret from the vault
    list                    List secrets for the specified vault group

OPTIONS:
Generic options (environment variable). You can specify the options on the command line or set an environment variable before running the ./cp-deploy.sh command:
  --status-dir,-l <dir>         Local directory to store logs and other provisioning files ($STATUS_DIR)
  --config-dir,-c <dir>         Directory to read the configuration from. Must be specified if configuration read from local server ($CONFIG_DIR)
  --config-repo-url,-r <url>    Git repository to retrieve the configuration from ($GIT_REPO_URL)
  --git-repo-dir,-rd <dir>      Directory in the Git repository that holds the configuration ($GIT_REPO_DIR)
  --git-access-token,-t <token> Token to authenticate to the Git repository ($GIT_ACCESS_TOKEN)
  --ibm-cloud-api-key <apikey>  API key to authenticate to the IBM Cloud ($IBM_CLOUD_API_KEY)
  --confirm-destroy             Confirm that infra may be destroyed. Required for action destroy and when apply destroys infrastructure ($CONFIRM_DESTROY)
  --cpd-develop                 Map current directory to automation scripts, only for development/debug ($CPD_DEVELOP)
  -vvv                          Show verbose ansible output ($ANSIBLE_VERBOSE)

Options for vault subcommand:
  --vault-group,-vg <name>          Group of secret ($VAULT_GROUP)
  --vault-secret,-vs <name>         Secret name to get, set or delete ($VAULT_SECRET)
  --vault-secret-value,-vsv <value> Secret value to set ($VAULT_SECRET_VALUE)
  ```

```

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. Please note that the the LOG_DATA_DIR directory must exist and that the current user must be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
IBM_CLOUD_API_KEY=your_api_key
ibm_cp4d_entitlement_key=your_cp4d_entitlement_key
LOG_DATA_DIR=/Data/sample-log
CONFIG_DIR=/Data/sample

./cp-deploy.sh env apply \
 --status-dir ${LOG_DATA_DIR} \
 --config-dir ${CONFIG_DIR} \
 --ibm-cloud-api-key ${IBM_CLOUD_API_KEY}
```

After the installation is completed, the Terraform tfstate file is stored into the vault. When re-running the automation script it fetches the tfstate file from the vault.

If you need to interrupt the automation, use CTRL-C to stop the output then use:
```
podman ps
```
If multiple containers are active you can double-check that you're terminating the correct container by doing a `podman logs <container name>`.

Then, stop the container as follows:
```
podman kill <container name>
```
