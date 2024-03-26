# Installing the Cloud Pak Deployer

## Prerequisites

To install and run the Cloud Pak Deployer, ensure that either podman or docker is available on your system. These are typically available on various Linux distributions such as Red Hat Enterprise Linux (preferred), Fedora, CentOS, Ubuntu, and MacOS. Note that Docker behaves differently on Windows compared to Linux platforms, potentially causing deployment issues.

### Using a Windows workstation

If you're working on a Windows workstation without access to a Linux server, you can use VirtualBox to create a Linux virtual machine for deployment.

* Install VirtualBox: https://www.virtualbox.org
* Install a Linux guest operating system: https://www.virtualbox.org/wiki/Guest_OSes

Once the guest operating system is set up, log in as root. VirtualBox supports port forwarding for easy access to the Linux command line using tools like PuTTY.

### Install on Linux

On Red Hat Enterprise Linux of CentOS, run the following commands:
```
yum install -y podman git
yum clean all
```

On MacOS, run the following commands:
```
brew install podman git
podman machine create
podman machine init
```

On Ubuntu, debian Based : 
```
apt-get -y install podman
podman machine create
podman machine init
```

Generally, adhere to the instructions provided to install either podman or docker on your Linux system.

## Clone the current repository

### Using the command line

If you clone the repository from the command line, you will need to enter a token when you run the `git clone` command. You can retrieve your token as follows:

Go to a directory where you want to download the Git repo.
```
git clone --depth=1 https://github.com/IBM/cloud-pak-deployer.git
```

## Build the image

First go to the directory where you cloned the GitHub repository, for example `~/cloud-pak-deployer`.
```
cd cloud-pak-deployer
```

Then run the following command to build the container image.
```
./cp-deploy.sh build
```

This process will take 5-10 minutes to complete and it will install all the pre-requisites needed to run the automation, including Ansible, Python and required operating system packages. For the installation to work, the system on which the image is built must be connected to the internet.

## Downloading the Cloud Pak Deployer Image from Registry

To download the Cloud Pak Deployer image from the Quay.io registry, you can use the Docker command-line interface (CLI) or Podman.

```bash
podman pull quay.io/cloud-pak-deployer/cloud-pak-deployer
```

This command pulls the latest version of the Cloud Pak Deployer image from the Quay.io repository. Once downloaded, you can use this image to deploy Cloud Paks

## Tags and Versions

By default, the above command pulls the latest version of the Cloud Pak Deployer image. If you want to specify a particular version or tag, you can append it to the image name. For example:

```bash
podman pull quay.io/cloud-pak-deployer/cloud-pak-deployer:<tag_or_version>
```

Replace `<tag_or_version>` with the specific tag or version you want to download.