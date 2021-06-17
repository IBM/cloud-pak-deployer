# Cloud Pak Deployer

![Provisioner pipeline](/images/Provisioner-pipeline.png)

## Installing the Cloud Pak Deployer

### Install pre-requisites
* Start with a server that has the Red Hat 8.x operating system installed.

> Please note that this must be a registered RHEL-8 system; CentOS or other will not work as the tool depends on the Red Hat Universal Base Image (UBI)
```
yum install -y podman git
yum clean all
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

### Create your configuration
The Cloud Pak Deployer requires the desired end-state to be configured in a pre-defined directory structure. This structure may exist on the server that runs the utility or can be pulled from a (branch of a) Git repository. 

#### Create configuration directory structure
Use the following directory structure; you can copy a template from the `./sample` directory in included in this repository.
```
CONFIG_DIR  --> /config
                - cp4d.yaml
                - roks.yaml
                - vpc.yaml
            --> /inventory
                - sample.inv
```

### Run the deployment
To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. Please note that the the LOG_DATA_DIR directory must exist and that the current user must be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.
```
IBM_CLOUD_API_KEY=your_api_key
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

The installation container will run in the background. You can monitor it as follows (this will show the logs of the latest container):
```
podman logs -f -l
```

After the installation is completed, the Terraform tfstate file is stored into IBM Vault. When re-running the automation script it fetches the tfstate file from the vault.

If you need to interrupt the automation, you can find the container as follows:
```
podman ps
```

If multiple containers are active you can double-check that you're terminating the correct container by doing a `podman logs <container name>`.

Then, stop the container as follows:
```
podman kill <container name>
```
