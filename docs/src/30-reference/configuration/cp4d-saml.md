# Cloud Pak for Data SAML configuration

You can configure Single Sign-on (SSO) by specifying a SAML server for the Cloud Pak for Data instance, which will take care of authenticating users. SAML configuration can be used in combination with the Cloud Pak for Data LDAP configuration, in which case LDAP complements the identity with access management (groups) for users.

## SAML configuration - `cp4d_saml_config`
An `cp4d_saml_config` entry holds connection information, certificates and field configuration that is needed in the exchange between Cloud Pak for Data user management and the identity provider (idP). The entry must created for every Cloud Pak for Data project that requires SAML authentication.

When a `cp4d_saml_config` entry exists for a certain `cp4d` project, the user management pods are updated with a `samlConfig.json` file and then restarted. If an entry is removed later, the file is removed and the pods restarted again. When no changes are needed, the file in the pod is left untouched and no restart takes place.

For more information regarding the Cloud Pak for Data SAML configuration, check the single sign-on documentation: https://www.ibm.com/docs/en/cloud-paks/cp-data/4.0?topic=client-configuring-sso

```
cp4d_saml_config:
- project: cpd
  entrypoint: "https://prepiam.ice.ibmcloud.com/saml/sps/saml20ip/saml20/login"
  field_to_authenticate: email
  sp_cert_secret: {{ env_id }}-cpd-sp-cert
  idp_cert_secret: {{ env_id }}-cpd-idp-cert
  issuer: "cp4d"
  identifier_format: ""
  callback_url: ""
```

The above configuration uses the IBM preproduction IAM server to delegate authentication to and authentication is done via the user's e-mail address. An issuer must be configured in the identity provider (idP) and the idP's certificate must be kept in the vault so Cloud Pak for Data can confirm its identity.

### Property explanation
| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| project  | Name of OpenShift project of the matching `cp4d` entry. The cp4d project must exist. | Yes       |  |
| entrypoint | URL of the identity provider (idP) login page                      | Yes       |  |
| field_to_authenticate | Name of the parameter to authenticate with the idP      | Yes       |  |
| sp_cert_secret | Vault secret that holds the private certificate to authenticate to the idP. If not specified, requests will not be signed.  | No       |  |
| idp_cert_secret | Vault secret that holds the public certificate of the idP. This confirms the identity of the idP  | Yes   |  |
| issuer | The name you chose to register the Cloud Pak for Data instance with your idP  | Yes   |  |
| identifier_format | Format of the requests from Cloud Pak for Data to the idP. If not specified, `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress` is used  | No   |  |
| callback_url | Specify the callback URL if you want to override the default of **cp4d_url**`/auth/login/sso/callback` | No | |

The `callbackUrl` field in the `samlConfig.json` file is automatically populated by the deployer if it is not specified by the `cp4d_saml_config` entry. It then consists of the Cloud Pak for Data base URL appended with `/auth/login/sso/callback`.

Before running the deployer with SAML configuration, ensure that the secret configured for `idp_cert_secret` exists in the vault. Check [Vault configuration](./vault) for instructions on adding secrets to the vault.