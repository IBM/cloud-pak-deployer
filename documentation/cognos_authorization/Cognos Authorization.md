# Automated Cognos Authorization using LDAP groups

![Authorization Overview](/images/cognos_authorization.png)

## Description
The automated cognos authorization capabilities uses LDAP groups to assign users to a Cognos Analytics Role, which allows these users to login to Cognos Analytics. This capability will perform the following tasks:
- Create a User Group and assign the associated LDAP Group(s) and Cloud Pak for Data role(s)
- For each member of the LDAP Group(s) part of the User Group, create the user as a Cloud Pak for Data User and assigned the Cloud Pak for Data role(s)
- For each member of the LDAP Group(s) part of the User Group, assign membership to the Cognos Analytics instance and authorize for the Cognos Analytics Role

If the User Group is already present, validate all LDAP Group(s) are associated with the User Group. Add the LDAP Group(s) not yet assiciated to the User Group. Existing LDAP groups will not be removed from the User Group

If a User is already present in Cloud Pak for Data, it will not be updated.

If a user is already associated with the Cognos Analytics instance, keep its original membership and do not update the membership

## Usage of the Script
The script is available in automation-roles/50-install-cloud-pak/cp4d-service/files/assign_CA_authorization.sh

Run the script without arguments to show its usage help.
```
# ./assign_CA_authorization.sh                                                                               
Usage:

assign_CA_authorization.sh
  <CLOUD_PAK_FOR_DATA_URL>
  <CLOUD_PAK_FOR_DATA_LOGIN_USER>
  <CLOUD_PAK_FOR_DATA_LOGIN_PASSWORD>
  <CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>
  <CLOUD_PAK_FOR_DATA_USER_GROUP_DESCRIPTION>
  <CLOUD_PAK_FOR_DATA_USER_GROUP_ROLES_ASSIGNMENT>
  <CLOUD_PAK_FOR_DATA_USER_GROUP_LDAP_GROUPS_MAPPING>
  <CLOUD_PAK_FOR_DATA_COGNOS_ANALYTICS_ROLE>
```

- **<CLOUD_PAK_FOR_DATA_URL>**: The URL to the IBM Cloud Pak for Data instance
- **<CLOUD_PAK_FOR_DATA_LOGIN_USER>**: The login user to IBM Cloud Pak for Data, e.g. the admin user
- **<CLOUD_PAK_FOR_DATA_LOGIN_PASSWORD>**: The login password to IBM Cloud Pak for Data
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>**: The Cloud Pak for Data User Group Name
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_DESCRIPTION>**: The Cloud Pak for Data User Group Description
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_ROLES_ASSIGNMENT>**: The Cloud Pak for Data roles associated to the User Group. Use a ; seperated list to assign multiple roles
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_LDAP_GROUPS_MAPPING>**: The LDAP Groups associated to the User Group. Use a ; seperated list to assign LDAP groups
- **<<CLOUD_PAK_FOR_DATA_COGNOS_ANALYTICS_ROLE>**: The Cognos Analytics Role each member of the User Group will be associated with, which must be one of:
  - Analytics Administrators
  - Analytics Explorers
  - Analytics Users
  - Analytics Viewer


## Running the script

### Pre-requisites
Prior to running the script, ensure:
- LDAP configuration in IBM Cloud Pak for Data is completed and validated
- Cognos Analytics instance is provisioned and running in IBM Cloud Pak for Data
- The role(s) that will be associated with the User Group are present in IBM Cloud Pak for Data

### Running the script with its arguments
Using the command example provided by the ./assign_CA_authorization.sh command, run the script
```
./assign_CA_authorization.sh
  https://...... \
  admin \
  ****** \
  "Cognos User Group" \
  "Cognos User Group Description" \
  "wkc_data_scientist_role;zen_administrator_role" \
  "cn=ca_group,ou=groups,dc=ibm,dc=com" \
  "Analytics Viewer"
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
