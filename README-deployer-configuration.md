# Cloud Pak Deployer Configuration

The structure and content of the configuration files must be as follows:

```
CONFIG_DIR  
  --> /config
      - client.yaml
  --> /inventory
      - client.inv
```

## /config/client.yaml

Placeholder for the client.yaml file

## /inventory/client.inv




### Vault configuration

The following Vault implementations can be used to store and retrieve secrets:
- IBM Cloud Vault
- Hashicorp Vault (token authentication)
- Hashicorp Vault (certificate authentication)
- Ansible Vault

A configuration example for each implementation is described below

#### IBM Cloud Vault (Secrets Manager)

The <secrets-manager-endpoint>.<region> is available at the **endpoints** section of the Secrets Manager in IBM Cloud.
```
vault_type=ibmcloud-vault
vault_authentication_type=api-key
vault_url=https://<secrets-manager-endpoint>.<region>.secrets-manager.appdomain.cloud
```

#### Hashicorp Vault (token authentication)

```
vault_type=hashicorp-vault
vault_authentication_type=api-key
vault_url=https://<hashicorp-vault-url>:8200
vault_secret_path=secret/base/path
vault_api_key=<hashicorp-vault-token>
vault_secret_field=value
```

- vault_secret_path:
  The base path of the location where the secrets are stores/retrieved
- vault_api_key:
  The access token to the Hashicorp vault
- vault_secret_field
  The field name used when storing/retrieving a secret

**note:**
It is strongly recommended not to store the **vault_api_key** in the inventory file when using a GIT repository for security reasons. Instead the vault_api_key can be passed as a parameter when running the container:
```
IBM_CLOUD_API_KEY=your_ibm_cloud_api_key
STATUS_DIR=/Data/sample-log
VAULT_API_KEY=hashicorp_vault_token

podman run \
  -d \
  -v ${STATUS_DIR}:/Data:Z \
  -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY} \
  -e vault_api_key=${VAULT_API_KEY}
  cloud-pak-deployer
```

#### Hashicorp Vault (certificate authentication)

```
vault_type=hashicorp-vault
vault_authentication_type=certificate
vault_url=https://<hashicorp_vault_url>:8200
vault_ca_cert=/Data/<ca_certificate_filename>
vault_client_cert=/Data/<client_certificate_filename>
vault_client_key=/Data/<client_key_certificate_filename>
vault_secret_path=secret/base/path
vault_secret_field=value
```

- vault_ca_cert
  CA certificate to trust the Hashicorp Vault TLS listener
- vault_client_cert
  Client certificate authorized to access the Hashicorp vault
- vault_client_key
  Client certificate key authorized to access the Hashicorp vault
- vault_secret_path:
  The base path of the location where the secrets are stores/retrieved
- vault_secret_field
  The field name used when storing/retrieving a secret

**note:**
It is strongly recommended that the file **vault_ca_cert**, **vault_client_cert** and **vault_client_key** are not in the GIT repository for security reasons. Instead when preparing to run the Cloud Pak Deployer, copy the certificate file to the /Data folder.

#### File Vault 
```
vault_type=file-vault
vault_directory=/Data/file-vault
vault_authentication_type=none
```

- vault_directory
  Location where the file vault is created
