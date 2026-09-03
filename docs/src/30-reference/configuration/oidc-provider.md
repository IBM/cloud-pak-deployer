# OpenID Conenct (OIDC configuration)

You can configure a generic OIDC Identity Provider (IdP). 

## OIDC Confifuration - `oidc_provider`
An `oidc_provider` resource indicates that an already configured OpenID Connect identity provider will be used.

```
oidc_provider:
- name: ibm-oidc
  discovery_url: "https://keycloak-ibm-keycloak.apps.itz-l43q72.hub04-lb.techzone.ibm.com/realms/master/.well-known/openid-configuration"
  client_id: ibm-oidc
  client_secret: ibm-oidc-client-secret
  token_attribute_mappings:
    groups: "groupIds"
    given_name: "given_name"
    family_name: "family_name"
    first_name: "given_name"
    last_name: "family_name"
    sub: "uid"
    email: "email"
```

The OIDC provider name is referenced in the [Zen Access Control](./cp4d-access-control.md#access-control---zen_access_control) resource and this is also where the mapping from OIDC groups to Cloud Pak for Data groups takes place. 

### Property explanation
| Property                | Description                                                                | Mandatory | Allowed values |
| ----------------------- | -------------------------------------------------------------------------- | --------- | -------------- |
| name.                   | Name of the OIDC provider                                                  | Yes       |                |
| discovery_url           | URL that can be used to get the OpenID Connect configuration               | Yes       |                |
| client_id               | Client ID of the OIDC client                                               | Yes       |                |
| client_secret           | Name of the vault secret that holds the client secret                      | Yes       |   |
| token_attribute_mappings | Mapping of the token attributes                                           | Yes       |   |