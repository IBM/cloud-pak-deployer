# Cloud Pak for Data instances

## Manage cloud Pak for Data instances

Some cartridges have the ability to create one or more instances to run an isolated installation of the cartridge. If instances have been configured for the cartridge, the deployer can manage creating and deleting the instances.

The following Cloud Pak for Data cartridges are currently supported for managing instances:

* [Analytics engine powered by Apache Spark](#analytics-engine-powered-by-apache-spark-instances) (`analytics-engine`)
* [DataStage](#datastage-instances) (`datastage-ent-plus`) 
* [Db2 OLTP](#db2-oltp-instances) (`db2`)
* [Data Virtualization](#data-virtualization-instances) (`dv`)
* [Cognos Analytics](#cognos-analytics-instance) (`ca`)
* [EDB Postgres](#edb-postgres-for-cloud-pak-for-data-instances) (`edb_cp4d`)
* [OpenPabes](#openpages-instance) (`openpages`)

### Analytics engine powered by Apache Spark Instances

Analytics Engine instances can be defined by adding the `instances` section to the `cartridges` entry of cartridge `analytics-engine`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: analytics-engine
    size: small
    state: installed
    instances:
    - name: analyticsengine-instance
      storage_size_gb: 50
```

| Property | Description | Mandatory | Allowed Values |
| -------- | ----------- | ---------- | ------------- |
| name | Name of the instance | Yes | |
| storage_size_db | Size of the storage allocated to the instance | Yes | numeric value |

### DataStage instances

DataStage instances can be defined by adding the `instances` section to the `cartridges` entry of cartridge `datastage-ent-plus`. The following example shows the configuration to define an instance.

DataStage, upon deployment, always creates a default instance called `ds-px-default`. This instance cannot be configured in the `instances` section. 

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: datastage-ent-plus
    state: installed

    instances:
    - name: ds-instance
      # Optional settings
      description: "datastage ds-instance"
      size: medium
      storage_class: efs-nfs-client
      storage_size_gb: 60
      # Optional Custom Scale options
      scale_px_runtime:
        replicas: 2
        cpu_request: 500m
        cpu_limit: 2
        memory_request: 2Gi
        memory_limit: 4Gi
      scale_px_compute:
        replicas: 2
        cpu_request: 1
        cpu_limit: 3
        memory_request: 4Gi
        memory_limit: 12Gi   
```

| Property | Description | Mandatory | Allowed Values |
| -------- | ----------- | ---------- | ------------- |
| name | Name of the instance | Yes | |
| description | Description of the instance | No | |
| size | Size of the DataStage instance | No | small (default), medium, large |
| storage_class | Override the default storage class | No |  |
| storage_size_gb | Storage size allocated to the DataStage instance | No | numeric |

Optionally, the default px_runtime and px_compute instances of the DataStage instance can be tweaked. Both `scale_px_runtime` and `scale_px_compute` must be specified when used, and all properties must be specified.

| Property | Description | Mandatory | 
| -------- | ----------- | ---------- | 
| replicas | Number of replicas | Yes | 
| cpu_request | CPU Request value | Yes |
| memory_request | Memory Request value | Yes |
| cpu_limit | CPU limit value | Yes |
| memory_limit | Memory limit value | Yes |

### Db2 OLTP Instances

DB2 OLTP instances can be defined by adding the `instances` section to the `cartridges` entry of cartridge `db2`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: db2
    size: small
    state: installed
    instances:
    - name: db2 instance
      metadata_size_gb: 20
      data_size_gb: 20
      backup_size_gb: 20  
      transactionlog_size_gb: 20
    
```

| Property | Description | Mandatory | Allowed Values |
| -------- | ----------- | ---------- | ------------- |
| name | Name of the instance | Yes | |
| metadata_size_gb | Size of the metadata store | Yes | numeric value |
| data_size_gb | Size of the data store | Yes | numeric value |
| backup_size_gb | Size of the backup store | Yes | numeric value |
| transactionlog_size_gb | Size of the transactionlog store | Yes | numeric value |

### Data Virtualization Instances

Data Virtualization instances can be defined by adding the `instances` section to the `cartridges` entry of cartridge `dv`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: dv
    size: small
    state: installed
    instances:
    - name: data-virtualization
```

| Property | Description | Mandatory | Allowed Values |
| -------- | ----------- | ---------- | ------------- |
| name | Name of the instance | Yes | |

### Cognos Analytics Instance

A Cognos Analytics instance can be defined by adding the `instances` section to the `cartridges` entry of cartridge `ca`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: ca
    size: small
    state: installed
    instances:
    - name: ca-instance
      metastore_ref: ca-metastore
```

| Property | Description | Mandatory | 
| -------- | ----------- | ---------- | 
| name | Name of the instance | Yes |
| metastore_ref | Name of the DB2 instance used for the Cognos Repository database | Yes |

The Cognos Content Repository database can use an IBM Cloud Pak for Data DB2 OLTP instance. The Cloud Pak Deployer will first determine whether an existing DB2 OLTP existing with the name specified `metastore_ref`. If this is the case, this DB2 OLTP instance will be used and the database is prepared using the Cognos DB2 script prior to provisioning the Cognos instance.

### EDB Postgres for Cloud Pak for Data instances

EnterpriseDB instances can be defined by adding the `instances` section to the `cartridges` entry of cartridge `dv`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:

  # Please note that for EDB Postgress, a secret edb-postgres-license-key must be created in the vault
  # before deploying
  - name: edb_cp4d
    size: small
    state: installed
    instances:
    - name: instance1
      version: "13.5"
      #Optional Parameters
      type: Standard
      members: 1
      size_gb: 50
      resource_request_cpu: 1000m
      resource_request_memory: 4Gi
      resource_limit_cpu: 1000m
      resource_limit_memory: 4Gi
```

| Property | Description | Mandatory | Allowed Values |
| -------- | ----------- | ---------- | ------------- |
| name | Name of the instance | Yes | |
| version | Version of the EDB PostGres instance | Yes | 12.11, 13.5 | 
| type | Enterprise or Standard version | No | Standard (default), Enterprise | 
| members | Number of members of the instance | No | number, 1 (default) | 
| size_gb | Storage Size allocated to the instance | No | number, 50 (default) | 
| resource_request_cpu | Request CPU of the instance | No | 1000m (default) | 
| resource_request_memory | Request Memory of the instance | No | 4Gi (default)  | 
| resource_limit_cpu | Limit CPU of the instance | No | 1000m (default) | 
| resource_limit_memory | Limit Memory of the instance | No |  4Gi (default) | 

### OpenPages Instance

An OpenPages instance can be defined by adding the `instances` section to the `cartridges` entry of cartridge `openpages`. The following example shows the configuration to define an instance.

```
cp4d:
- project: cpd-instance
  openshift_cluster_name: "{{ env_id }}"
...
  cartridges:
  - name: openpages
    state: installed
    instances:
    - name: openpages-instance
      size: xsmall
```

| Property | Description | Mandatory | 
| -------- | ----------- | ---------- | 
| name | Name of the instance | Yes |
| size | The size of the OpenPages instances, default is xsmall | No |
