# Installing the Cloud Pak Deployer

## Install pre-requisites
The Cloud Pak Deployer requires `podman` or `docker` to run, which are available on most Linux distributions such as Red Hat Enterprise Linux (preferred), Fedora, CentOS and Ubuntu. Due to changed licensing policies we are no longer testing the deployer using Docker desktop on Macbook. Also, on Windows Docker behaves differently than Linux platforms and this can cause the deployer to fail.

### Using a Macbook or Windows workstation
If you don't have a Linux server in some cloud, you can use VirtualBox to create a Linux virtual machine.

* Install VirtualBox: https://www.virtualbox.org
* Install a Linux guest operating system: https://www.virtualbox.org/wiki/Guest_OSes

Once the guest operating system is up and running, log on as root to the guest operating system. For convenience, VirtualBox also supports port forwarding so you can using `ssh` or `PuTTY` to access the Linux command line.

### Install on Linux
On Red Hat Enterprise Linux of CentOS, run the following commands:
```
yum install -y podman git
yum clean all
```

On Ubuntu, follow the instructions here: https://docs.docker.com/engine/install/ubuntu/

## Clone the current repository

### Using GitHub Desktop

* Open GitHub Desktop
* Select **Clone a Repository from the Internet**
* Go to the **URL** tab and enter: https://github.com/IBM/cloud-pak-deployer.git
* Specify the local path where you want to store the repository
* You will be prompted for a user and password. Enter your GitHub user name and the token you generated above

### Using the command line
If you clone the repository from the command line, you will need to enter a token when you run the `git clone` command. You can retrieve your token as follows:

Go to a directory where you want to download the Git repo.
```
git clone https://github.com/IBM/cloud-pak-deployer.git
```
You wil be prompted for user and password. Enter your GitHub user name and the token you generated above.

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