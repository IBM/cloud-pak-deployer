# Vault configuration

## Vault configuration
Throughout the deployment process, the Cloud Pak Deployer will create secrets in a vault and retrieve them later. Examples of secrets are: ssh keys, Cloud Pak for Data admin password. Additionally, when provisioning infrastructure no the IBM Cloud, the resulting Terraform state file is also stored in the vault so it can be used later if the configuration needs to be changed.

Configuration of the vault is done through a `vault` object in the configuration. If you want to use the file-based vault in the status directory, you do not need to configure anything.

The following Vault implementations can be used to store and retrieve secrets:
- File Vault (no encryption)
- IBM Cloud Secrets Manager
- Hashicorp Vault (token authentication)
- Hashicorp Vault (certificate authentication)

The **File Vault** is the default vault and also the simplest. It does not require a password and all secrets are stored in base-64 encoding in a properties file under the `<status_directory>/vault` directory. The name of the vault file is the `environment_name` you specified in the global configuration, inventory file or at the command line.

All of the other vault options require some secret manager (IBM Cloud service or Hashicorp Vault) to be available and you need to specify a password or provide a certificate.

Sample Vault config:
```
vault:
  vault_type: file-vault
  vault_authentication_type: none
```

### Properties for all vault implementations

| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| vault_type | Chosen implementation of the vault                                 | Yes       | file-vault, ibmcloud-vault, hashicorp-vault |

### Properties for `file-vault`

| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| vault_authentication_type | Authentication method for the file vault            | No        | none          |

### Properties for `ibmcloud-vault`

| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| vault_authentication_type | Authentication method for the file vault            | No        | api-key          |
| vault_url | URL for the IBM Cloud secrets manager instance                      | Yes       |           |

### Properties for `hashicorp-vault`

| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| vault_authentication_type | Authentication method for the file vault            | No        | api-key, certificate   |
| vault_url | URL for the Hashicorp vault, this is typically https://hostname:8200 | Yes       |           |
| vault_api_key | When authentication type is api-key, the field to authenticate with | Yes       |           |
| vault_secret_path | Default secret path to store and retrieve secrets into/from | Yes       |           |
| vault_secret_field | Default field to store or retrieve secrets | Yes       | |
| vault_secret_path_append_group | Determines whether or not the secrete group will be appended to the path | Yes       | True (default), False |
| vault_secret_base64 | Depicts if secrets are stored in base64 format for Hashicorp Vault | Yes       | True (default), False |