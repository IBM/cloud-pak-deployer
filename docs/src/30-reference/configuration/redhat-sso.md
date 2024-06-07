# Red Hat Single Sign-on (SSO) configuration

You can configure Red Hat Single Sign-on (SSO) to be installed on the OpenShift cluster as an Identity Provider (IdP). Red Hat SSO implements the open-source Keycloak project which offers a user registry and can also federate other IdPs.

## Red Hat SSO configuration - `openshift_redhat_sso`
An `openshift_redhat_sso` resource indicates that the Red Hat Single Sign-on operator must be installed on the referenced OpenShift cluster. A single SSO configuration can have only 1 Keycloak realms defined. The Keycloak realm holds all configuration needed for authentication. If you want to host more than 1 Keycloak server on the cluster, specify multiple `openshift_redhat_sso` entries, each with its own `keycloak_name`. The `keycloak_name` also determines the OpenShift project that will be created.

```
openshift_redhat_sso:
- openshift_cluster_name: "{{ env_id }}"
  keycloak_name: ibm-keycloak
  groups:
  - name: kc-cp4d-admins
    state: present
  - name: kc-cp4d-data-engineers
    state: present
  - name: kc-cp4d-data-scientists
    state: present
  - name: kc-cp4d-monitors
    state: present
```

The above configuration installs the Red Hat SSO operator in OpenShift project `ibm-keycloak` and creates a Keycloak instance named `ibm-keycloak`. The instance has a single realm: `master` which contains the groups, users and clients which are then leveraged by Cloud Pak Foundational Services.

Currently you can only define Keycloak groups which are later mapped to Cloud Pak for Data user groups. Creating users and setting up federated identity providers must be done by logging into Keycloak.

The Keycloak name is referenced in the [Zen Access Control](./cp4d-access-control.md#access-control---zen_access_control) resource and this is also where the mapping from Keycloak groups to Cloud Pak for Data groups takes place. 

### Property explanation
| Property                | Description                                                                | Mandatory | Allowed values |
| ----------------------- | -------------------------------------------------------------------------- | --------- | -------------- |
| openshift_cluster_name  | Name of OpenShift cluster onto which the Red Hat SSO operator is installed | Yes. if more than 1 `openshift` resource in the configuration |                |
| keycloak_name           | Name of the Keycloak server, this also determines the name of the project into which the Keycloak server will be created | Yes       |                |
| .groups[]               | Groups that will be created in the Keycloak realm                          | Yes       |                |
| .name                   | Name of the Keycloak group                                                 | Yes       |                |
| .state                  | Whether the group is present or absent                                     | Yes       | `present`, `absent` |