# Cloud Pak for Data LDAP

Cloud Pak for Data can connect to an LDAP user registry for identity and access managment (IAM). When configured, for a Cloud Pak for Data instance, a user must authenticate with the user name and password stored in the LDAP server.

If [SAML](./cp4d-saml) is also configured for the Cloud Pak for Data instance, authentication (identity) is managed by the SAML server but access management (groups, roles) can still be served by LDAP.

## Cloud Pak for Data LDAP configuration

![LDAP_Overview](images/ldap_user_groups.png "LDAP connection and User Groups")

IBM Cloud Pak for Data can connect to an LDAP user registry in order for users to log on with their LDAP credentials. The configuration of LDAP can be specified in a seperate yaml file in the `config` folder, or included in an existing yaml file.

### LDAP configuration - `cp4d_ldap_config`

A `cp4d_ldap_config` entry contains the connectivity information to the LDAP user registry. The `project` and `openshift_cluster_name` values uniquely identify the Cloud Pak for Data instance.
The `ldap_domain_search_password_vault` entry contains a reference to the vault, which means that as a preparation the LDAP bind user password must be stored in the vault used by the Cloud Pak Deployer using the key referenced in the configuration. 
If the password is not available, the Cloud Pak Deployer will fail and not able to configure the LDAP connectivity.

```
# Each Cloud Pak for Data Deployment deployed in an OpenShift Project of an OpenShift cluster can have its own LDAP configuration
cp4d_ldap_config:
- project: cpd-instance
  openshift_cluster_name: sample                                         # Mandatory
  ldap_host: ldaps://ldap-host                                           # Mandatory
  ldap_port: 636                                                         # Mandatory
  ldap_user_search_base: ou=users,dc=ibm,dc=com                          # Mandatory
  ldap_user_search_field: uid                                            # Mandatory
  ldap_domain_search_user: uid=ibm_roks_bind_user,ou=users,dc=ibm,dc=com # Mandatory
  ldap_domain_search_password_vault: ldap_bind_password                  # Mandatory, Password vault reference
  auto_signup: "false"                                                   # Mandatory
  ldap_group_search_base: ou=groups,dc=ibm,dc=com                        # Optional, but mandatory when using user groups
  ldap_group_search_field: cn                                            # Optional, but mandatory when using user groups
  ldap_mapping_first_name: cn                                            # Optional, but mandatory when using user groups
  ldap_mapping_last_name: sn                                             # Optional, but mandatory when using user groups
  ldap_mapping_email: mail                                               # Optional, but mandatory when using user groups
  ldap_mapping_group_membership: memberOf                                # Optional, but mandatory when using user groups
  ldap_mapping_group_member: member                                      # Optional, but mandatory when using user groups
```

The above configuration uses the LDAPS protocol to connect to port `636` on the `ldap-host` server. This server can be a private server if an upstream DNS server is also defined for the OpenShift cluster that runs Cloud Pak for Data. Common Name `uid=ibm_roks_bind_user,ou=users,dc=ibm,dc=com` is used as the bind user for the LDAP server and its password is retrieved from vault secret `ldap_bind_password`.

### User Group configuration - `cp4d_user_group_configuration`
The `cp4d_user_group_configuration:` can optionally create User Group(s) with references to LDAP Group(s). A `user_groups` entry must contain at least 1 `role_assignments` and 1 `ldap_groups` entry.

```
# Each Cloud Pak for Data Deployment deployed in an OpenShift Project of an OpenShift cluster can have its own User Groups configuration
cp4d_user_group_configuration:
- project: zen-sample                                                    # Mandatory
  openshift_cluster_name: sample                                         # Mandatory
  user_groups:
  - name: CA_Analytics_Viewer
    description: User Group for Cognos Analytics Viewers
    role_assigmnents:
    - name: zen_administrator_role
    ldap_groups:
    - name: cn=ca_viewers,ou=groups,dc=ibm,dc=com
  - name: CA_Analytics_Administrators
    description: User Group for Cognos Analytics Administrators
    role_assigmnents:
    - name: zen_administrator_role
    ldap_groups:
    - name: cn=ca_admins,ou=groups,dc=ibm,dc=com
```

**Role Assignment values:**
- zen_administrator_role
- zen_user_role
- wkc_data_scientist_role
- zen_developer_role
- zen_data_engineer_role (requires installation of DataStage cartridge to become available)

During the creation of User Group(s) the following validations are performed:
- LDAP configuration is completed
- The provided role assignment(s) are available in Cloud Pak for Data
- The provided LDAP group(s) are available in the LDAP registry
- If the User Group already exists, it ensures the provided LDAP Group(s) are assigned, but no changes to the existing role assignments are performed and no LDAP groups are removed from the User Group

### Provisioned instance authorization - `cp4d_instance_configuration`
When using Cloud Pak for Data LDAP connectivity and User Groups, the User Groups can be assigned to authorize the users of the LDAP groups access to the proviosioned instance(s).

Currently supported instance authorization:  
- Cognos Analytics (ca)

#### Cognos Analytics instance authorization

![Cognos Analytics Authorization](images/cognos_authorization.png "Cognos Analytics Authorization")

```
cp4d_instance_configuration:
- project: zen-sample                # Mandatory
  openshift_cluster_name: sample     # Mandatory
  cartridges:
  - name: cognos_analytics
    manage_access:                                  # Optional, requires LDAP connectivity
    - ca_role: Analytics Viewer                     # Mandatory, one the CA Access roles
      cp4d_user_group: CA_Analytics_Viewer          # Mandatory, the CP4D User Group Name
    - ca_role: Analytics Administrators             # Mandatory, one the CA Access roles
      cp4d_user_group: CA_Analytics_Administrators  # Mandatory, the CP4D User Group Name
```

A Cognos Analytics (ca) instance can have multiple `manage_access` entries. Each entry consists of 1 `ca_role` and 1 `cp4d_user_group` element. 
The `ca_role` must be one of the following possible values:
- Analytics Administrators
- Analytics Explorers
- Analytics Users 
- Analytics Viewer

During the configuration of the instance authorization the following validations are performend:
- LDAP configuration is completed
- The provided `ca_role` is valid
- The provided `cp4d_user_group` exists
