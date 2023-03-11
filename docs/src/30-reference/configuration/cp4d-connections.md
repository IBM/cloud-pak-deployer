# Cloud Pak for Data platform connections

## Cloud Pak for Data platform connection - `cp4d_conection`
The `cp4d_connection` object can be used to create Global Platform connections.

```
cp4d_connection:
- name: connection_name                                 # Name of the connection, must be unique
  type: database                                        # Type, currently supported: [database]
  cp4d_instance: cpd                                    # CP4D instance on which the connection must be created
  openshift_cluster_name: cluster_name                  # OpenShift cluster name on which the cp4d_instance is deployed
  database_type: db2                                    # Type of connection
  database_hostname: hostname                           # Hostname of the connection
  database_port: 30556                                  # Port of the connection
  database_name: bludb                                  # Database name of the connection
  database_port_ssl: true                               # enable ssl flag
  database_credentials_username: 77066f69               # Username of the datasource
  database_credentials_password_secret: db-credentials  # Vault lookup name to contain the password
  database_ssl_certificate_secret: db-ssl-cert          # Vault lookup name to contain the SSL certificate
```

## Cloud Pak for Data backup and restore platform connections - `cp4d_backup_restore_connections`
The `cp4d_backup_restore_connections` can be used to backup all current configured Global Platform connections, which are either created by the Cloud Pak Deployer or added manually. The backup is stored in the `status`/cp4d/exports folder as a json file. 

A backup file can be used to restore global platform connections. A flag can be used to indicate whether if a Global Platform connection with the same name already exists, the restore is skipped.

Using the Cloud Pak Deployer cp4d_backup_restore_connections capability implements the following:
- Connect to the IBM Cloud Pak for Data instance specified using `cp4d_instance` and `openshift_cluster_name`
- If `connections_backup_file` is specified export all Global Platform connections to the specified file in the `status`/cp4d/export/connections folder
- If `connections_restore_file` is specified, load the file and restore the Global Platform connections
- The `connections_restore_overwrite` (true/false) indicates whether if a Global Platform Connection with the same already exists, it will be replaced.

```
cp4d_backup_restore_connections:
- cp4d_instance: cpd
  openshift_cluster_name: {{ env_id }}
  connections_backup_file: {{ env_id }}_cpd_connections.json
  connections_restore_file: {{ env_id }}_cpd_connection.json
  connections_restore_overwrite: false
```