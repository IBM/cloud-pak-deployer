# OpenLDAP configuration (for demonstration purposes only)

You can install an OpenLDAP service on your OpenShift cluster for demonstration and testing purposes. This way you can experiment with LDAP identity providers in Foundational Services if you don't (yet) have access to an enterprise-ready LDAP service in the organization's infrastructure services.

**Note** Installing an OpenLDAP server must only be done if you have unrestricted OpenShift Container Platform entitlements. When using the Cloud Pak entitlements for Red Hat OpenShift, installing third-party applications like Bitnami OpenLDAP is not allowed.

## Demonstration OpenLDAP configuration - `demo_openldap`
A `demo_ldap` resource in the configuration indicates that the Bitname OpenLDAP service is installed on the specified OpenShift cluster. The default OpenShift poject for the OpenLDAP service is `openldap`. You can install several instances on the same OpenShift cluster if necessary, each with its own name and `openldap_project` project.

Sample configuration
```
demo_openldap:
- name: cp4d-openldap
  openshift_cluster_name: "{{ env_id }}"
  openldap_project: openldap
  ldap_config:
    ldap_tls: True
    bind_admin_user: cn=admin,dc=cp,dc=internal
    base_dn: dc=cp,dc=internal
    base_dc: cp
    base_domain: cp.internal
    user_ou: Users
    user_id_attribute: uid
    user_display_name_attribute: cn
    user_base_dn: ou=Users,dc=cp,dc=internal
    user_object_class: inetOrgPerson
    group_ou: Groups
    group_id_attribute: cn
    group_display_name_attribute: cn
    group_base_dn: ou=Groups,dc=cp,dc=internal
    group_object_class: groupOfUniqueNames
    group_member_attribute: uniqueMember
  users:
  - uid: ttoussaint
    givenName: Tara
    sn: Toussaint
    mail: ttoussaint@cp.internal
  - uid: rramones
    givenName: Rosa
    sn: Ramones
    mail: rramones@cp.internal
    # password: specific_password_for_the_user
  - uid: ssharpe
    givenName: Shelly
    sn: Sharpe
    mail: ssharpe@cp.internal
    # password: specific_password_for_the_user
  - uid: pprimo
    givenName: Paco
    sn: Primo
    mail: pprimo@cp.internal
    # password: specific_password_for_the_user
  - uid: rroller
    givenName: Rico
    sn: Roller
    mail: rroller@cp.internal
    # password: specific_password_for_the_user
  groups:
  - cn: cp4d-admins
    members:
    - uid=ttoussaint,ou=Users,dc=cp,dc=internal
  - cn: cp4d-data-engineers
    members:
    - uid=rramones,ou=Users,dc=cp,dc=internal
    - uid=ssharpe,ou=Users,dc=cp,dc=internal
  - cn: cp4d-data-scientists
    members:
    - uid=pprimo,ou=Users,dc=cp,dc=internal
    - uid=ssharpe,ou=Users,dc=cp,dc=internal
    - uid=rroller,ou=Users,dc=cp,dc=internal
  state: installed
```

The above configuration installs the OpenLDAP service in OpenShift project `openldap` and configures it for domain `cp.internal`. Subsequently, an LDIF file with the Organization Units, Groups and Users is generated and then the OpenLDAP service is started. 

The OpenLDAP name is referenced in the [Cloud Pak for Data Access Control](./cp4d-access-control.md#cloud-pak-for-data-access-control) resource and this is also where the mapping from LDAP groups to Cloud Pak for Data groups takes place. 

### Property explanation
| Property                | Description                                                                | Mandatory | Allowed values |
| ----------------------- | -------------------------------------------------------------------------- | --------- | -------------- |
| name                    | Name of the OpenLDAP server, for reference by `zen_access_control`         | Yes       |                |
| openshift_cluster_name  | Name of OpenShift cluster into which the OpenLDAP service is installed     |Yes. if more than 1 `openshift` resource in the configuration |                |
| openldap_project        | OpenShift project into which the OpenLDAP server is installed              | No, default is `openldap` | |
| ldap_config             | LDAP configuration                                                         | Yes       |                |
| .ldap_tls               | Set to True if the LDAPS protocol just be used to communicate with the LDAP server | No | False (default), True |
| .bind_admin_user        | Distinguished name of the user to bind (login) to the LDAP server          | Yes       |                |
| .base_dn                | Base domain name, specify through `dc` components                          | Yes       |                |
| .base_dc                | First `dc` component in the `base_dn`                                      | Yes       |                |
| .base_domain            | Base domain of the LDAP root, specified as `cp.internal`                   | Yes       |                |
| .user_ou                | Organizational Unit of users, typically `Users`                            | Yes       |                |
| .user_id_attribute      | Attribute used to identify user, typically `uid`                           | Yes       |                |
| .user_display_name_attribute | Common name of the user, typically `cn`                               | Yes       |                |
| .user_base_dn           | Base domain name of users, typically `user_ou`, followed by `base_dn`      | Yes       |                |
| .user_object_class      | Object class of the users, typically `inetOrgPerson`                       | Yes       |                |
| .group_ou               | Organizational Unit of groups, typically `Groups`                          | Yes       |                |
| .group_id_attribute     | Attribte used to idenfity group, typically `cn`                            | Yes       |                |
| .group_display_name_attribute | Common name of the group, typically `cn`                             | Yes       |                |
| .group_base_dn          | Base domain name of groups, typically `group_ou`, followed by `base_dn`    | Yes       |                |
| .group_object_class     | Object class of the gruops, typically `groupOfUniqueNames`                 | Yes       |                |
| .group_member_attribute | Attribute used for a member (user) of a group, typically `uniqueMember`    | Yes       |                |
| users[]                 | List of users to be added to the LDAP configuration                        | Yes       |                |
| .uid                    | User identifier that is used to login to the platform                      | Yes       |                |
| .givenName              | First name of the user                                                     | Yes       |                |
| .sn                     | Surname of the user                                                        | Yes       |                |
| .mail                   | e-mail address of the user                                                 | Yes       |                |
| .password               | Password to be assigned to the user. If not specified, the universal password is used | No |            |
| groups[]                | List of groups to be added to the LDAP configuration                       | Yes       |                |
| .cn                     | Group identifier, together with the `group_ou` and `base_dn`, this will define the group to map to the Cloud Pak group(s) | Yes | |
| .members[]              | List of user distinguished names to be added as members to the group       | Yes       |                |
| state                   | Indicates whether or nog OpenLDAP must be installed                        | Yes       | `installed`, `removed` |