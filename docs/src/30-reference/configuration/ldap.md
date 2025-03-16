# LDAP configuration

You can reference an LDAP service that is available in the organization's infrastructure services.

## LDAP configuration - `ldap`

Sample configuration for LDAP
```
ldap:
- name: cp4d-ldap
  ldap_url: ldap://openldap.cp4d-openldap.svc:389
  ldap_base_dn: dc=cp,dc=internal
  ldap_bind_dn: cn=admin,dc=cp,dc=internal
  ldap_bind_password_vault_secret: cp-internal-ldap-bind-password
  ldap_group_filter: '(&(cn=%v)(objectclass=groupOfUniqueNames))'
  ldap_group_id_map: '*:cn'
  ldap_group_member_id_map: 'groupOfUniqueNames:uniqueMember'
  ldap_user_filter: '(&(uid=%v)(objectclass=inetOrgPerson))'
  ldap_user_id_map: '*:uid'
  ldap_case_insensitive: False
```

Sample configuration for LDAPS
```
ldap:
- name: cp4d-ldap
  ldap_url: ldaps://openldap.cp4d-openldap.svc:646
  ldap_tls_verify_client: demand
  ldap_tls_client_cert_vault_secret: cp4d-openldap-cert
  ldap_tls_client_key_vault_secret: cp4d-openldap-key
  ldap_base_dn: dc=cp,dc=internal
  ldap_bind_dn: cn=admin,dc=cp,dc=internal
  ldap_bind_password_vault_secret: cp-internal-ldap-bind-password
  ldap_group_filter: '(&(cn=%v)(objectclass=groupOfUniqueNames))'
  ldap_group_id_map: '*:cn'
  ldap_group_member_id_map: 'groupOfUniqueNames:uniqueMember'
  ldap_user_filter: '(&(uid=%v)(objectclass=inetOrgPerson))'
  ldap_user_id_map: '*:uid'
  ldap_case_insensitive: False
```


The LDAP name is referenced in the [Cloud Pak for Data Access Control](./cp4d-access-control.md#cloud-pak-for-data-access-control) resource and this is also where the mapping from LDAP groups to Cloud Pak for Data groups takes place. 

### Property explanation
| Property                | Description                                                                | Mandatory | Allowed values |
| ----------------------- | -------------------------------------------------------------------------- | --------- | -------------- |
| name                    | Name of the LDAP server, for reference by `zen_access_control`             | Yes       |                |
| ldap_url                | The URL of the LDAP server, including protocol and port                    | Yes       |                |
| ldap_tls_verify_client  | Option that matches the TLSVerifyClient setting of the LDAP server         | No        | try, demand    |
| ldap_tls_client_cert_vault_secret | Certificate of the LDAP server                                   | No        |                |
| ldap_tls_client_key_vault_secret | Key of the LDAP server                                            | No        |                |
| ldap_url                | The URL of the LDAP server, including protocol and port                    | Yes       |                |
| ldap_url                | The URL of the LDAP server, including protocol and port                    | Yes       |                |
| ldap_base_dn            | Base domain name, specify through `dc` components                          | Yes       |                |
| ldap_bind_dn            | The bind user of the LDAP server                                           | No        |                |
| ldap_bind_password_vault_secret | The deployer vault secret that holds the password of the bind user | No        |                |
| ldap_group_filter       | The filter clause for searching groups                                     | Yes       |                |
| ldap_group_id_map       | The filter to map a group name to an LDAP entry                            | Yes       |                |
| ldap_group_member_id_map | The filter to map a user to a group                                       | Yes       |                |
| ldap_user_filter        | The filter clause for searching users                                      | Yes       |                |
| ldap_user_id_map        | The filter to map a username to an LDAP entry                              | Yes       |                |
| ldap_case_insensitive   | Indicates whether user names are case insensitive                          | No        | False (default), True |

!!! info
    Please make sure that the bind password is stored in the vault secret specified in the `ldap_bind_password_vault_secret` property. Use `cp-deploy.sh vault set -vs=your_secret_name=your_bind_password` to set the vault secret before running the deployer. 
    
    If your LDAP server supports anonymous binding and you do not want to authenticate, do not specify the `ldap_bind_dn` and `ldap_bind_password_vault_secret`.