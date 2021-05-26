# platform-provision-automation

## Running the platform automation

### Install pre-requisites
* Start with a Red Hat 8.x operating system
```
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
yum install -y python3 ansible tar unzip expect git wget jq
yum clean all
```

Install Terraform
```
TER_VER=0.15.1
wget https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip
unzip terraform_${TER_VER}_linux_amd64.zip
mv terraform /usr/local/bin/
```

### Create configuration directory
Use the following directory structure.
```
CONFIG_DIR  --> /config
                - cp4d.yaml
                - roks.yaml
                - vpc.yaml
                            --> /templates
                                - roks_default.yaml
                                - ...
            --> /inventory
                - sample.inv
```

### Run the automation
```
export IBM_CLOUD_API_KEY=<Your_API_Key>
export CONFIG_DIR=<Directory_with_your_configuration>
docker-scripts/run_automation.sh
```

