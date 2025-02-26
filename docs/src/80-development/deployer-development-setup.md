# Deployer Development Setup
Setting up a virtual machine or server to develop the Cloud Pak Deployer code. Focuses on initial setup of a server to run the deployer container, setting up Visual Studio Code, issuing GPG keys and running the deployer in development mode.

## Set up a server for development
We recommend to use a Red Hat Linux server for development of the Cloud Pak Deployer, either using a virtual server in the cloud or a virtual machine on your workstation. Ideally you run Visual Studio Code on your workstation and connect it to the remote Red Hat Linux server, updating the code and running it immediately from that server.

### Install required packages
To allow for remote development, a number of packages need to be installed on the Linux server. Not having these will cause VSCode not to work and the error messages are difficult to debug. To install these packages, run the following as the `root` user:
``` { .bash .copy }
yum install -y git podman wget unzip tar gpg pinentry
```

Additionally, you can also install EPEL and `screen` to make it easier to keep your session if it gets disconnected.
``` { .bash .copy }
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum install -y screen
```

### Set up development user
It is recommended to use a special development user (your user name) on the Linux server, rather than using `root`. Not only will this be more secure; it also prevent destructive mistakes. In the below steps, we create a user `fk-dev` and give it `sudo` permissions.

``` { .bash .copy }
useradd -G wheel fk-dev
```

To give the `fk-dev` permissions to run commands as `root`, change the `sudo` settings.
``` { .bash .copy }
visudo
```

Scroll down until you see the following line:
``` { .bash .copy }
# %wheel        ALL=(ALL)       NOPASSWD: ALL
```

Change the line to look like this:
``` { .bash .copy }
%wheel        ALL=(ALL)       NOPASSWD: ALL
```

Now, save the file by pressing Esc, followed by `:` and `x`.

### Configure password-less SSH for development user
Especially when running the virtual server in the cloud, users would logon using their SSH key. This requires the public key of the workstation to be added to the development user's SSH configuration.

Make sure you run the following commands as the development user (fk-dev):
``` { .bash .copy }
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Then, add the public key of your workstation to the `authorized_keys` file.
``` { .bash .copy }
vi ~/.ssh/authorized_keys
```

Press the `i` to enter insert mode for `vi`. Then paste the public SSH key, for example:
``` { .bash .copy }
ssh-rsa AAAAB3NzaC1yc2EAAAADAXABAAABAQEGUeXJr0ZHy1SPGOntmr/7ixmK3KV8N3q/+0eSfKVTyGbhUO9lC1+oYcDvwMrizAXBJYWkIIwx4WgC77a78....fP3S5WYgqL fk-dev
```

Finally save the file by pressing Esc, followed by `:` and `x`.

### Configure Git for the development user
Run the following commands as the development user (fk-dev):
``` { .bash .copy }
git config --global user.name "Your full name"
git config --global user.email "your_email_address"
git config --global credential.helper "cache --timeout=86400"
```

### Set up GPG for the development user
We also want to ensure that commits are verified (trusted) by signing them with a GPG key. This requires set up on the development server and also on your Git account.

First, set up a new GPG key:
``` { .bash .copy }
gpg --default-new-key-algo rsa4096 --gen-key
```

You will be prompted to specify your user information:

* Real name: Enter your full name
* Email address: Your e-mail address that will be used to sign the commits

Press `o` at the following prompt:
```output
Change (N)ame, (E)mail, or (O)kay/(Q)uit?
```

Then, you will be prompted for a passphrase. You cannot use a passphrase for your GPG key if you want to use it for automatic signing of commits. Just press Enter multiple times until the GPG key has been generated.

List the signatures of the known keys. You will use the signature to sign the commits and to retrieve the public key.
``` { .bash .copy }
gpg --list-signatures
```

Output will look something like this:
```output
/home/fk-dev/.gnupg/pubring.kbx
-----------------------------------
pub   rsa4096 2022-10-30 [SC] [expires: 2024-10-29]
      BC83E8A97538EDD4E01DC05EA83C67A6D7F71756
uid           [ultimate] FK Developer <fk-dev@ibm.com>
sig 3        A83C67A6D7F71756 2022-10-30  FK Developer <fk-dev@ibm.com>
```

You will use the signature to retrieve the public key:
```
gpg --armor --export A83C67A6D7F71756
```

The public key will look something like below:
```output
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGNeGNQBEAC/y2tovX5s0Z+onUpisnMMleG94nqOtajXG1N0UbHAUQyKfirt
O8t91ek+e5PEsVkR/RLIM1M1YkiSV4irxW/uFPucXHZDVH8azfnJjf6j6cXWt/ra
1I2vGV3dIIQ6aJIBEEXC+u+N6rWpCOF5ERVrumGFlDhL/PY8Y9NM0cNQCbOcciTV
5a5DrqyHC3RD5Bcn5EA0/5ISTCGQyEbJe45G8L+a5yRchn4ACVEztR2B/O5iOZbM
.
.
.
4ojOJPu0n5QLA5cI3RyZFw==
=sx91
-----END PGP PUBLIC KEY BLOCK-----
```

Now that you have the signature, you can configure Git to sign commits:
``` { .bash .copy }
git config --global user.signingkey A83C67A6D7F71756
git config --global commit.gpgsign true
```

Next, add your GPG key to your Git user.

* Go to https://github.com/IBM/cloud-pak-deployer.git
* Log in using your public GitHub user
* Click on your user at the top right of the pages
* Click **select**
* In the left menu, select **SSH and GPG keys**
* Click **New GPG key**
* Enter a meaningful title for your GPG key, for example: **FK Development Server**
* Paste the public GPG key
* Confirm by pushing the **Add GPG key** button

Commits done on your development server will now be signed with your user name and e-mail address and will show as **Verified** when listing the commits.


### Clone the repository
Clone the repository using a `git` command. The command below is the clone of the main Cloud Pak Deployer repository. If you have forked the repository to develop features, you will have to use the URL of your own fork.
``` { .bash .copy }
git clone https://github.com/IBM/cloud-pak-deployer.git
```

### Connect VSCode to the development server

* Install the **Remote - SSH** extension in VSCode
* Click on the green icon in the lower left of VSCode
* Open SSH Config file, choose the one in your home directory
* Add the following lines:
```output
Host nickname_of_your_server
   HostName ip_address_of_your_server
   User fk-dev
```

Once you have set up this server in the SSH config file, you can connect to it and start remote development. 

* Open
* Select the `cloud-pak-deployer` directory (this is the cloned repository)
* As the directory is a cloned Git repo, VSCode will automatically open the default branch

From that point forward you can use VSCode as if you were working on your laptop, make changes and use a separate terminal to test your changes.

## Cloud Pak Deployer developer command line option
The Cloud Pak Deployer runs as a container on the server. When you're in the process of developing new features, having to always rebuild the image is a bit of a pain, hence we've introduced a special command line parameter.

``` { .bash .copy }
source ./set-env.sh
```

``` { .bash .copy }
cp-deploy.sh env apply .... --cpd-develop [--accept-all-liceneses]
```

When adding the `--cpd-develop` parameter to the command line, the current directory is mapped as a volume to the `/cloud-pak-deployer` directory within the container. This means that any latest changes you've done to the Ansible playbooks or other commands will take effect immediately.

!!! warning
    Even though it is possible to run the deployer multiple times in parallel, for different environments, please be aware that is NOT possible when you use the `--cpd-develop` parameter. If you run two deploy processes with this parameters, you will see errors with permissions.

## Cloud Pak Deployer developer container image tag
When working on multiple changes concurrently, you may have to switch between branches or tags. By default, the Cloud Pak Deployer image is built with image `latest`, but you can override this by setting the `CPD_IMAGE_TAG` environment variable in your session.

``` { .bash .copy }
source ./set-env.sh
```

``` { .bash .copy }
export CPD_IMAGE_TAG=cp4d-460
cp-deploy.sh build
```

When building the deployer, the image is now tagged:
``` { .bash .copy }
podman image ls
```

```output
REPOSITORY                           TAG         IMAGE ID      CREATED        SIZE
localhost/cloud-pak-deployer         cp4d-460    8b08cb2f9a2e  8 minutes ago  1.92 GB
```

When running the deployer with the same environment variable set, you will see an additional message in the output.
``` { .bash .copy }
cp-deploy.sh env apply
```

```output
Cloud Pak Deployer image tag cp4d-460 will be used.
...
```

## Cloud Pak Deployer podman or docker command
By default, the `cp-deploy.sh` command detects if `podman` (preferred) or `docker` is found on the system. In case both are present, `podman` is used. You can override this behaviour by setting the `CPD_CONTAINER_ENGINE` environment variable.

``` { .bash .copy }
source ./set-env.sh
```

``` { .bash .copy }
export CPD_CONTAINER_ENGINE=docker
cp-deploy.sh build
```

```output
Container engine docker will be used.
```