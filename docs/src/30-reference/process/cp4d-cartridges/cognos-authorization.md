# Automated Cognos Authorization using LDAP groups

![Authorization Overview](cognos_authorization.png)

## Description
The automated cognos authorization capability uses LDAP groups to assign users to a Cognos Analytics Role, which allows these users to login to IBM Cloud Pak for Data and access the Cognos Analytics instance. This capability will perform the following tasks:
- Create a User Group and assign the associated LDAP Group(s) and Cloud Pak for Data role(s)
- For each member of the LDAP Group(s) part of the User Group, create the user as a Cloud Pak for Data User and assigned the Cloud Pak for Data role(s)
- For each member of the LDAP Group(s) part of the User Group, assign membership to the Cognos Analytics instance and authorize for the Cognos Analytics Role

If the User Group is already present, validate all LDAP Group(s) are associated with the User Group. Add the LDAP Group(s) not yet assiciated to the User Group. Existing LDAP groups will not be removed from the User Group

If a User is already present in Cloud Pak for Data, it will not be updated.

If a user is already associated with the Cognos Analytics instance, keep its original membership and do not update the membership

## Pre-requisites
Prior to running the script, ensure:
- LDAP configuration in IBM Cloud Pak for Data is completed and validated
- Cognos Analytics instance is provisioned and running in IBM Cloud Pak for Data
- The role(s) that will be associated with the User Group are present in IBM Cloud Pak for Data

## Usage of the Script
The script is available in [automation-roles/50-install-cloud-pak/cp4d-service/files/assign_CA_authorization.sh](https://github.com/IBM/cloud-pak-deployer/automation-roles/50-install-cloud-pak/cp4d-service/files/assign_CA_authorization.sh).

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

- **<CLOUD_PAK_FOR_DATA_URL>**  The URL to the IBM Cloud Pak for Data instance
- **<CLOUD_PAK_FOR_DATA_LOGIN_USER>** The login user to IBM Cloud Pak for Data, e.g. the admin user
- **<CLOUD_PAK_FOR_DATA_LOGIN_PASSWORD>** The login password to IBM Cloud Pak for Data
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>** The Cloud Pak for Data User Group Name
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_DESCRIPTION>** The Cloud Pak for Data User Group Description
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_ROLES_ASSIGNMENT>** The Cloud Pak for Data roles associated to the User Group. Use a ; seperated list to assign multiple roles
- **<CLOUD_PAK_FOR_DATA_USER_GROUP_LDAP_GROUPS_MAPPING>** The LDAP Groups associated to the User Group. Use a ; seperated list to assign LDAP groups
- **<CLOUD_PAK_FOR_DATA_COGNOS_ANALYTICS_ROLE>** The Cognos Analytics Role each member of the User Group will be associated with, which must be one of:
  - Analytics Administrators
  - Analytics Explorers
  - Analytics Users
  - Analytics Viewer

## Running the script

Using the command example provided by the `./assign_CA_authorization.sh` command, run the script with its arguments
```
# ./assign_CA_authorization.sh \
  https://...... \
  admin \
  ******** \
  "Cognos User Group" \
  "Cognos User Group Description" \
  "wkc_data_scientist_role;zen_administrator_role" \
  "cn=ca_group,ou=groups,dc=ibm,dc=com" \
  "Analytics Viewer"
```
The script execution will run through the following tasks:

**Validation**  
Confirm all required arguments are provided.  
Confirm at least 1 User Group Role assignment is provided.  
Confirm at least 1 LDAP Group is provided.

**Login to Cloud Pak for Data and generate a Bearer token**  
Using the provided IBM Cloud for Data URL, username and password, login to Cloud pak for Data and generate the Bearer token used for subsequent commands. Exit with an error if the login to IBM Cloud Pak for Data fails. 

**Confirm the provided User Group role(s) are present in Cloud Pak for Data**  
Acquire all Cloud Pak for Data roles and confirm the provided User Group role(s) are one of the existing Cloud Pak for Data roles. Exit with an error if a role is provided which is not currently present in IBM Cloud Pak for Data.

**Confirm the provided Cognos Analytics role is valid**  
Ensure the provided Cognos Analytics role is one of the available Cognos Analytics roles. Exit with an error if a Cognos Analytics role is provided that does not match with the available Cognos Analytics roles.

**Confirm LDAP is configured in IBM Cloud Pak for Data**  
Ensures the LDAP configuration is completed. Exit with an error if there is no current LDAP configuration.

**Confirm the provided LDAP groups are present in the LDAP User Registry**  
Using IBM Cloud Pak for Data, query whether the provided LDAP groups are present in the LDAP User registry. Exit with an error if a LDAP Group is not available.

**Confirm if the IBM Cloud Pak for Data User Group exists**  
Queries the IBM Cloud Pak for Data User Groups. If the provided User Group exists, acquire the Group ID. 

**If the IBM Cloud Pak for Data User Group does not exist, create it**  
If the User Group does not exist, create it, and assign the IBM Cloud Pak for Data Roles and LDAP Groups to the new User Group

**If the IBM Cloud Pak for Data User Group does exist, validate the associated LDAP Groups**  
If the User Group already exists, confirm all provided LDAP groups are associated with the User Group. Add LDAP groups that are not yet associated.

**Get the Cognos Analytics instance ID**  
Queries the IBM Cloud Pak for Data service instances and acquires the Cognos Analytics instance ID. Exit with an error if no Cognos Analytics instance is available

**Ensure each user member of the IBM Cloud Pak for Data User Group is an existing user**  
Each user that is member of the provided LDAP groups, ensure this member is an IBM Cloud Pak for Data User. Create a new user with the provided User Group role(s) if the the user is not yet available. Any existing User(s) will not be updated. If Users are removed from an LDAP Group, these users will not be removed from Cloud Pak for Data. 

**Ensure each user member of the IBM Cloud Pak for Data User Group is associated to the Cognos Analytics instance**  
Each user that is member of the provided LDAP groups, ensure this member is associated to the Cognos Analytics instance with the provided Cognos Analytics role. Any user that is already associated to the Cognos Analytics instance will have its Cognos Analytics role updated to the provided Cognos Analytics Role