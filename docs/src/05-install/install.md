# Installing the Cloud Pak Deployer

## Install pre-requisites
The Cloud Pak Deployer requires `podman` or `docker` to run, which are available on most Linux distributions such as Red Hat Enterprise Linux (preferred), Fedora, CentOS, Ubuntu and MacOS. On Windows Docker behaves differently than Linux platforms and this can cause the deployer to fail.

### Using a Windows workstation
If you don't have a Linux server in some cloud, you can use VirtualBox to create a Linux virtual machine.

* Install VirtualBox: https://www.virtualbox.org
* Install a Linux guest operating system: https://www.virtualbox.org/wiki/Guest_OSes

Once the guest operating system is up and running, log on as root to the guest operating system. For convenience, VirtualBox also supports port forwarding so you can use `PuTTY` to access the Linux command line.

#### Using WSL2
WSL allows you to run a Linux distribution alongside your Windows installation.

1. Open PowerShell as Administrator and run:
```
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```
2. Install WSL 2 by running:
```
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
3. Set WSL 2 as the default version:
```
wsl --set-default-version 2
```
4. Installing a Linux Distribution on WSL
Install a Linux distribution from the Microsoft Store (e.g., Ubuntu, Debian).
Launch the distribution to complete the installation.
Set up your username and password.
Install following "Install on Linux"


### Install on Linux

Linux distributions often come with their own package managers. Here are some common ones:

#### DNF (Fedora/RHEL)
```
sudo dnf install package-name
```

#### APT (Debian/Ubuntu)
```
sudo apt update
sudo apt install package-name
```

#### On MacOS, run the following commands:
```
brew install podman git
podman machine create
podman machine init
```

#### Pacman (Arch Linux)
```
sudo pacman -S package-name
```

#### Zypper (openSUSE)
```
sudo zypper install package-name
```

## Clone the current repository

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

# Getting Cloud Pak Deployer Image from Quay.io
You can obtain the Cloud Pak Deployer image from the Quay.io container registry. This method allows you to fetch the image directly from the repository. Here's a step-by-step guide on how to do this:

1. Login to Quay.io
Before pulling the Cloud Pak Deployer image, you need to log in to your Quay.io account or create one if you don't have it.
```
docker login quay.io
```

2. Pull the Cloud Pak Deployer Image

Using Docker : 
```
docker pull quay.io/cloud-pak-deployer/cloud-pak-deployer
```

Using podman 
```
podman pull quay.io/cloud-pak-deployer/cloud-pak-deployer
```

# Air-gapped :
In air-gapped environments where direct internet access is restricted, you can build Docker images on one Linux server and then transfer them to another server using a combination of Docker's docker cp command and the scp (Secure Copy Protocol) utility.

1. Build the Deployer image on Server A

2. Save the Docker Image as a Tarball:
```
docker save -o cloud-pak-deployer.tar cloud-pak-deployer:latest
```
3. Copy the tarball from Server A to Server B using scp:
```
scp /path/to/cloud-pak-deployer.tar user@ServerB:/path/to/destination/
```
4. Load the Docker image from the tarball on Server B
```
docker load -i /path/to/destination/cloud-pak-deployer.tar
```