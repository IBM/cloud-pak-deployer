# Configure the Cloud Pak(s)

This stage focuses on post-installation configuration of the Cloud Paks and cartridges.

## Cloud Pak for Data

### Web interface certificate
When provisioning on IBM Cloud ROKS, a CA-signed certificate for the ingress subdomain is automatically generated in the IBM Cloud certificate manager. The deployer retrieves the certificate and adds it to the secret that stores the certificate key. This will avoid getting a warning when opening the Cloud Pak for Data home page.

### Configure identity and access management
For Cloud Pak for Data you can configure:

* SAML for Single Sign-on. When specified in the `cp4d_saml_config` object, the deployer configures the user management pods to redirect logins to the identity provider (idP) of choice.
* LDAP configuration. LDAP can be used both for authentication (if no SSO has been configured) and for access management by mapping LDAP groups to Cloud Pak for Data user groups. Specify the LDAP or LDAPS properties in the `cp4d_ldap_config` object so that the deployer configures it for Cloud Pak for Data. If SAML has been configured for authentication, the configured LDAP server is only used for access management.
* User group configuration. This creates user-defined user groups in Cloud Pak for Data to match the LDAP configuration. The configuration object used for this is `cp4d_user_group_configuration`.

### Provision instances
Some cartridges such as Data Virtualization have the ability to create one or more instances to run an isolated installation of the cartridge. If instances have been configured for the cartridge, this steps provisions them.
The following Cloud Pak for Data cartridges are currently supported for creating instances:

* Analytics engine powered by Apache Spark (`analytics-engine`)
* Db2 OLTP (`db2`)
* Cognos Analytics (`ca`)
* Data Virtualization (`dv`)

### Configure instance access
Cloud Pak for Data does not support group-defined access to cartridge instances. After creation of the instances (and also when the deployer is run with the `--cp-config-only` flag), the permissions of users accessing the instance is configured.

For Cognos Analytics, the [Cognos Authorization](cp4d-cartridges/cognos-authorization.md) process is run to apply user group permissions to the Cognos Analytics instance.

### Create or change platform connections
Cloud Pak for Data defines data source connections at the platform level and these can be reused in some cartridges like Watson Knowledge Catalog and Watson Studio. The `cp4d_connection` object defines each of the platform connections that must be managed by the deployer.

### Backup and restore connections
If you want to back up or restore platform connections, the `cp4d_backup_restore_connections` object defines the JSON file that will be used for backup and restore.

