# Cloud Pak for Data cartridges

Defines the services (cartridges) which must be installed into the Cloud Pak for Data instances. The cartridges will be configured with the storage class defined at the Cloud Pak for Data object level. For each cartridge you can specify whether it must be installed or removed by specifying the state. If a cartridge is installed and the state is changed to `removed`, the cartridge and all of its instances are removed by the deployer when it is run.

An example Cloud Pak for Data object with cartridges is below:
```
cp4d:
- project: cpd-instance
  cp4d_version: 4.8.3

  cartridges:
  - name: cpfs

  - name: cpd_platform

  - name: db2oltp
    size: small
    instances:
    - name: db2-instance
      metadata_size_gb: 20
      data_size_gb: 20
      backup_size_gb: 20
      transactionlog_size_gb: 20
    state: installed

  - name: wkc
    size: small
    state: removed

  - name: wml
    size: small
    state: installed

  - name: ws
    state: installed
```

When run, the deployer installs the Db2 OLTP (`db2oltp`), Watson Machine Learning (`wml`) and Watson Studio (`ws`) cartridges. If the Watson Knowledge Catalog (`wkc`) is installed in the `cpd-instance` OpenShift project, it is removed.

After the deployer installs Db2 OLTP, a new Db2 instance is created with the specified attributes.

## Cloud Pak for Data cartridges

### `cp4d.cartridges`
This is a list of cartridges that will be installed in the Cloud Pak for Data instance. Every cartridge is identified by its name.

Some cartridges may require additional information to correctly install or to create an instance for the cartridge. Below you will find a list of all tested Cloud Pak for Data cartridges and their specific properties.

#### Properties for all cartridges
| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| name     | Name of the cartridge                                         | Yes | |
| state     | Whether the cartridge must be `installed` or `removed`. If not specified, the cartridge will be installed | No | installed, removed |
| installation_options | Record of properties that will be applied to the `spec` of the OpenShift Custom Resource | No | |

### Cartridge `cpfs` or `cp-foundation`
Defines the Cloud Pak Foundational Services (fka Common Services) which are required for all Cloud Pak for Data installations. Cloud Pak for Data Foundational Services provide functionalities around identity and access management (IAM) and other common services.

This cartridge is mandatory for every Cloud Pak for Data and watsonx instance.

#### Additional properties for cartridge `cp-foundation`
| Property | Description                                                                                                  | Mandatory | Allowed values                              |
| -------- | ------------------------------------------------------------------------------------------------------------ | --------- | ------------------------------------------- |
| scale    | Scale configuration of Foundational Services. If the property is not provided, the scale will not be changed | No        | level_1, level_2, level_3, level_4, level_5 |
| license_service | Properties that will be applied to the IBM license service                                            |           |                                             |
| .threads_per_core | Specify the threads per core (hyperthreading) that the license service must use to calculate usage  | No        | 1 (default), numeric value                  |

### Cartridge `cpd_platform` or `lite`
Defines the Cloud Pak for Data platform operator (fka "lite") which installs the base services needed to operate Cloud Pak for Data, such as the Zen metastore, Zen watchdog and the user interface.

This cartridge is mandatory for every Cloud Pak for Data instance.

### Cartridge `wkc`
Manages the Watson Knowledge Catalog installation for the Cloud Pak for Data instance.

#### Additional properties for cartridge `wkc`
| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| size     | Scale configuration of the cartridge                                 | No        | small (default), medium, large |
| installation_options.install_wkc_core_only | Install only the core of WKC?      | No | True, False (default) |
| installation_options.enableKnowledgeGraph  | Enable the knowledge graph for business lineage? | No | True, False (default) |
| installation_options.enableDataQuality     | Enable data quality for WKC?       | No | True, False (default) |
| installation_options.enableMANTA           | Enable MANTA?                      | No | True, False (default) |
