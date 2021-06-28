# Cloud Pak Deployer

![Provisioner pipeline](/images/provisioning-process.png)

The Cloud Pak Deployer uses ansible playbooks to validate, prepare, provision, install and configure the underlying infrastructure and IBM Cloud Pak for Data platform. 
The playbooks are controlled by a configuration yaml file that is either located on the server from where the deployer is executed or sourced from a GIT repository.

## Installing the Cloud Pak Deployer

### Install pre-requisites
* Start with a server that has the Red Hat 8.x operating system installed.

> Please note that this must be a registered RHEL-8 system; CentOS or other will not work as the tool depends on the Red Hat Universal Base Image (UBI)
```
yum install -y podman git
yum clean all
```

### Clone the Cloud Pak Deployer repository
```
git clone https://github.ibm.com/DAPPER/platform-provision-automation
```

### Build the image
The container image must be built from the directory that holds the `Dockerfile` file.
```
cd cloud-pak-deployer
podman build -t cloud-pak-deployer .
```
This process will take 2-10 minutes to complete and it will install all the pre-requisites needed to run the automation, including Ansible, Terraform and operating system packages. For the installation to work, the system on which the image is built must be connected to the internet.

The build process wil also publish a volume `/Data`. The volume can be used when running the Cloud Pak the Deployer to make a persistent volume using the `-v` flag:
- Persist the log files of the Cloud Pak Deployer and access them from outside the podman pod
- Map the configuration yaml file. This is optional as the configuration yaml can also be pulled from a git repository

Note that if the cloud-pak-deployer image already exists and a new build is required, use the following steps to delete and build the image
```
podman rmi cloud-pak-deployer
cd cloud-pak-deployer
podman build -t cloud-pak-deployer .
```

## Using the Cloud Pak Deployer

### Create your configuration
The Cloud Pak Deployer requires the desired end-state to be configured in a pre-defined directory structure. This structure may exist on the server that runs the utility or can be pulled from a (branch of a) Git repository. 

#### Create configuration directory structure

This configuration can be created using one of the following scenario's:
- Create a local CONFIG_DIR and map this to the /Data volume of the Cloud Pak Deployer

Use the following local directory structure; you can copy a template from the `./sample-config` directory in included in this repository.
```
CONFIG_DIR  --> /config
                - client.yaml
            --> /inventory
                - client.inv
```

- Use a remote GIT repository where the CONFIG_DIR is location. During the execution of the Cloud Pak Deployer, a pull from the repository is performed before running the playbooks.

```
GIT_REPO/GIT_REPO_DIR --> /config
                          - client.yaml
                      --> /inventory
                          - client.inv
```

### Run the deployment (local CONFIG_DIR)
To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. Please note that the the LOG_DATA_DIR directory must exist and that the current user must be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.
```
IBM_CLOUD_API_KEY=your_ibm_cloud_api_key
LOG_DATA_DIR=/Data/sample-log
CONFIG_DIR=/Data/sample

podman run \
  -d \
  -v ${LOG_DATA_DIR}:/Data:Z \
  -v ${CONFIG_DIR}:${CONFIG_DIR}:Z \
  -e CONFIG_DIR=${CONFIG_DIR} \
  -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY} \
  cloud-pak-deployer
```

### Run the deployment (remote CONFIG_DIR)
To run the container using a remote GIT repository configuration, use the example below. Please note that the the LOG_DATA_DIR directory must exist and that the current user must be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.
```
IBM_CLOUD_API_KEY=your_ibm_cloud_api_key
LOG_DATA_DIR=/Data/sample-log
GIT_REPO_URL=https://github.ibm.com/<ACCOUNT>/<REPO>
GIT_ACCESS_TOKEN=your_config_git_access_token
GIT_REPO_DIR=sample-config

podman run \
  -d \
  -v ${LOG_DATA_DIR}:/Data:Z \
  -e GIT_REPO_URL=${GIT_REPO_URL} \
  -e GIT_ACCESS_TOKEN=${GIT_ACCESS_TOKEN} \
  -e GIT_REPO_DIR=${GIT_REPO_DIR} \
  -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY} \
  cloud-pak-deployer
```

### Monitoring the deployment

The installation container will run in the background. You can monitor it as follows:
```
podman logs -f cloud-pak-deployer
```

After the installation is completed, the Terraform tfstate file is stored into the vault that is configured in the inventory file. When re-running the automation script it fetches the tfstate file from the vault.

If you need to interrupt the automation, you can find the container as follows:
```
podman ps
podman kill cloud-pak-deplyer
```

If multiple containers are active or the container was build using a different name, you can double-check that you're terminating the correct container by doing a `podman logs <container name>`.

Then, stop the container as follows:
```
podman kill <container name>
```
