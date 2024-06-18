# Cloud Paks

Defines the Cloud Pak(s) which is/are layed out on the OpenShift cluster, typically in one or more OpenShift projects. The Cloud Pak definition represents the instance users connect to and which is responsible for managing the functional capabilities installed within the application.

## Cloud Pak configuration

- [Cloud Pak for Data](#cp4d)
- [Cloud Pak for Integration](#cp4i)
- [Cloud Pak for Watson AIOps](#cp4waiops)
- [Cloud Pak for Business Automation](#cp4ba)

## `cp4d`

Defines the Cloud Pak for Data instances to be configured on the OpenShift cluster(s).

```yaml
cp4d:
- project: cpd
  openshift_cluster_name: sample
  cp4d_version: 4.7.3
  sequential_install: False
  use_fs_iam: False
  change_node_settings: True
  db2u_limited_privileges: False
  accept_licenses: False
  openshift_storage_name: nfs-storage
  cp4d_entitlement: cpd-enterprise
  cp4d_production_license: True
  
  cartridges:
  - name: cpfs
  - name: cpd_platform
```

### Properties

| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| project  | Name of the OpenShift project of the Cloud Pak for Data instance     | Yes       |  |
| openshift_cluster_name | Name of the OpenShift cluster                  | Yes, inferred from openshift       | Existing `openshift` cluster |
| cp4d_version | Cloud Pak for Data version to install, this will determine the version for all cartridges that do not specify a version | Yes | 4.x.x |
| sequential_install | If set to `True` the deployer will run the **OLM utils** playbooks to install catalog sources, subscriptions and CRs. If set to `False`, deployer will use OLM utils to generate the scripts and then run them, which will cause the catalog sources, subscriptions and CRs to be created immediately and install in parallel | No | True (default), False |
| use_fs_iam | If set to `True` the deployer will enable Foundational Services IAM for authentication | No | False (default), True |
| change_node_settings | Controls whether the node settings using the machine configs will be applied onto the OpenShift cluster. | No | True, False |
| db2u_limited_privileges | Depicts whether Db2U containers run with limited privileges. If they do (`True`), Deployer will create KubeletConfig and Tuned OpenShift resources as per the documentation. | No | False (default), True |
| accept_licenses | Set to 'True' to accept Cloud Pak licenses. Alternatively the `--accept-all-licenses` can be used for the `cp-deploy.sh` command | No | True, False (default) |
| cp4d_entitlement | Set to `cpd-enterprise`, `cpd-standard`, `watsonx-data`, `watsonx-ai`, `watsonx-gov-model-management`, `watsonx-gov-risk-compliance`, dependent on the deployed license | No | cpd-enterprise (default), cpd-standard, watsonx-data, watsonx-ai, watsonx-gov-model-management, watsonx-gov-risk-compliance |
| cp4d_production_license | Whether the Cloud Pak for Data is a production license | No | True (default), False |
| image_registry_name | When using private registry, specify name of `image_registry` | No       |  |
| openshift_storage_name | References an `openshift_storage` element in the OpenShift cluster that was defined for this Cloud Pak for Data instance. The name must exist under `openshift.[openshift_cluster_name].openshift_storage. | No, inferred from openshift->openshift_storage | |
| cartridges | List of cartridges to install for this Cloud Pak for Data instance. See [Cloud Pak for Data cartridges](../../../30-reference/configuration/cp4d-cartridges) for more details | Yes | |

## `cp4i`

Defines the Cloud Pak for Integration installation to be configured on the OpenShift cluster(s).

```yaml
cp4i:
- project: cp4i
  openshift_cluster_name: {{ env_id }}
  openshift_storage_name: nfs-rook-ceph
  cp4i_version: 2021.4.1
  accept_licenses: False
  use_top_level_operator: False
  top_level_operator_channel: v1.5
  top_level_operator_case_version: 2.5.0
  operators_in_all_namespaces: True
 
  instances:
  - name: integration-navigator
    type: platform-navigator
    license: L-RJON-C7QG3S
    channel: v5.2
    case_version: 1.5.0
```

### OpenShift projects

The immediate content of the cp4i object is actually a list of OpenShift projects (namespaces). There can be more than one project and instances can be created in separate projects.

```yaml
cp4i:
- project: cp4i
  ...

- project: cp4i-ace
  ...

- project: cp4i-apic
  ...

```

#### Operator channels, CASE versions, license IDs

Before you run the Cloud Pak Deployer be sure that the correct operator channels are defined for the selected instance types. Some products require a license ID, please check the documentation of each product for the correct license. If you decide to use CASE files instead of the IBM Operator Catalog (more on that below) make sure that you selected the correct CASE versions - please refer: <https://github.com/IBM/cloud-pak/tree/master/repo/case>

### CP4I main properties

The following properties are defined on the project level:

| Property                        | Description |  Mandatory  | Allowed values |
|---------------------------------|-------------|-------------|----------------|
| project                         | The name of the OpenShift project that will be created and used for the installation of the defined instances. | Yes  | |
| openshift_cluster_name          | Dynamically defined form the `env_id` parameter during the execution. | Yes, inferred from openshift       | Existing `openshift` cluster |
| openshift_storage_name          | Reference to the storage definition that exists in the `openshift` object (please see above). The definition must include the class name of the file storage type and the class name of the block storage type. | No, inferred from openshift->openshift_storage | |
| cp4i_version                    | The version of the Cloud Pak for Integration (e.g. 2021.4.1) | Yes | |
| use_case_files                  | The property defines if the CASE files are used for installation. If it is True then the operator catalogs are created from the CASE files. If it is False, the **IBM Operator Catalog** from the entitled registry is used. | No | True, False (default) |
| accept_licenses | Set to `True` to accept Cloud Pak licenses. Alternatively the `--accept-all-licenses` can be used for the `cp-deploy.sh` command | Yes | True, False |
| use_top_level_operator          | If it is `True` then the CP4I top-level operator that installs all other operators is used. Otherwise, only the operators for the selected instance types are installed. | No | True, False (default) |
| top_level_operator_channel      | Needed if the `use_top_level_operator` is `True` otherwise, it is ignored. Specifies the channel of the top-level operator. | No | |
| top_level_operator_case_version | Needed if the `use_top_level_operator` is `True` otherwise, it is ignored. Specifies the CASE package version of the top-level operator. | No | |
| operators_in_all_namespaces     | It defines whether the operators are visible in all namespaces or just in the specific namespace where they are needed.  | No | True, False (default) |
| instances                       | List of the instances that are going to be created (please see below). | Yes | |

!!! warning  
    Despite the properties *use_case_files*, *use_top_level_operator* and *operators_in_all_namespaces* are defined as optional, they are actually crucial for the way of execution of the installation process. If any of them is omitted, it is assumed that the default *False* value is used. If none of them exists, it means that all are *False*. In this case, it means that the *IBM Operator Catalog* is used and only the needed operators for specified instance types are installed in the specific namespace.

### Properties of the individual instances

The *instance* property contains one or more instances definitions. Each instance must have a unique name. There can be more the one instance of the same type.

#### Naming convention for instance types

For each instance definition, an **instance type** must be specified. We selected the type names that are as much as possible similar to the naming convention used in the Platform Navigator use interface. The following table shows all existing types:

| Instance type              | Description/Product name |
|----------------------------|-------------|
| platform-navigator         | Platform Navigator |
| api-management             | IBM API Connect  |
| automation-assets          | Automation assets a.k.a Asset repo |
| enterprise-gateway         | IBM Data Power |
| event-endpoint-management  | Event endpoint manager - managing asynchronous APIs |
| event-streams              | IBM Event Streams - Kafka |
| high-speed-transfer-server | Aspera HSTS |
| integration-dashboard      | IBM App Connect Integration Dashboard |
| integration-design         | IBM App Connect Designer |
| integration-tracing        | Operations Dashboard |
| messaging                  | IBM MQ |

#### Platform navigator

The Platform Navigator is defined as one of the instance types. There is typically only one instance of it. The exception would be an installation in two or more completely separate namespaces (see the CP4I documentation). Special attention is paid to the installation of the Navigator. The Cloud Pak Deployer will install the Navigator instance first, before any other instance, and it will wait until the instance is ready (this could take up to 45 minutes).  

When the installation is completed, you will find the **admin** user password in the **status/cloud-paks/cp4i-<cluster_name>-cp4i-PN-access.txt** file. Of course, you can obtain the password also from the **platform-auth-idp-credentials** secret in **ibm-common-services** namespace.

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **platform-navigator** | |
| license                    | License ID           | L-RJON-C7QG3S |
| channel                    | Subscription channel | v5.2          |
| case_version               | CASE version         | 1.5.0         |

#### API management (IBM API Connect)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **api-management** | |
| license                    | License ID             | L-RJON-C7BJ42 |
| version                    | Version of API Connect | 10.0.4.0      |
| channel                    | Subscription channel   | v2.4          |
| case_version               | CASE version           | 3.0.5         |

#### Automation assets (Asset repo)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **automation-assets** | |
| license                    | License ID             | L-PNAA-C68928 |
| version                    | Version of Asset repo  | 2021.4.1-2 |
| channel                    | Subscription channel   | v1.4 |
| case_version               | CASE version           | 1.4.2 |

#### Enterprise gateway (IBM Data Power)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **enterprise-gateway** | |
| admin_password_secret      | The name of the secret where admin password is stored. The default name is used if you leave it empty. |  |
| license                    | License ID             | L-RJON-BYDR3Q |
| version                    | Version of Data Power | 10.0-cd |
| channel                    | Subscription channel   | v1.5 |
| case_version               | CASE version           | 1.5.0 |

#### Event endpoint management

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **event-endpoint-management** | |
| license                    | License ID             | L-RJON-C7BJ42 |
| version                    | Version of Event endpoint manager | 10.0.4.0 |
| channel                    | Subscription channel   | v2.4 |
| case_version               | CASE version           | 3.0.5 |

#### Event streams

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **event-streams** | |
| version                    | Version of Event streams | 10.5.0 |
| channel                    | Subscription channel   | v2.5 |
| case_version               | CASE version           | 1.5.2 |

#### High speed transfer server (Aspera HSTS)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **high-speed-transfer-server** | |
| aspera_key                 | A license key for the Aspera software | |
| redis_version              | Version of the Redis database | 5.0.9 |
| version                    | Version of Aspera HSTS | 4.0.0 |
| channel                    | Subscription channel   | v1.4 |
| case_version               | CASE version           | 1.4.0 |

#### Integration dashboard (IBM App Connect Dashboard)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **integration-dashboard** | |
| license                    | License ID             | L-APEH-C79J9U |
| version                    | Version of IBM App Connect | 12.0 |
| channel                    | Subscription channel   | v3.1 |
| case_version               | CASE version           | 3.1.0 |

#### Integration design (IBM App Connect Designer)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **integration-design** | |
| license                    | License ID             | L-KSBM-C87FU2 |
| version                    | Version of IBM App Connect | 12.0 |
| channel                    | Subscription channel   | v3.1 |
| case_version               | CASE version           | 3.1.0 |

#### Integration tracing (Operation dashborad)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **integration-tracing** | |
| version                    | Version of Integration tracing | 2021.4.1-2 |
| channel                    | Subscription channel   | v2.5 |
| case_version               | CASE version           | 2.5.2 |

#### Messaging (IBM MQ)

| Property                   | Description | Sample value for 2021.4.1 |
|----------------------------|-------------|----------------------------|
| name                       | Unique name within the cluster using only lowercase alphanumerics and "-" | |
| type                       | It must be **messaging** | |
| queue_manager_name         | The name of the initial queue. Default is *QUICKSTART* | |
| license                    | License ID             | L-RJON-C7QG3S |
| version                    | Version of IBM MQ | 9.2.4.0-r1 |
| channel                    | Subscription channel   | v1.7 |
| case_version               | CASE version           | 1.7.0 |

## `cp4waiops`

Defines the Cloud Pak for Watson AIOps installation to be configured on the OpenShift cluster(s). The following instances can be installed by the deployer:

- AI Manager
- Event Manager
- Turbonomic
- Instana
- Infrastructure management
- ELK stack (ElasticSearch, Logstash, Kibana)

Aside from the base install, the deployer can also install ready-to-use demos for each of the instances

```yaml
cp4waiops:
- project: cp4waiops
  openshift_cluster_name: "{{ env_id }}"
  openshift_storage_name: auto-storage
  accept_licenses: False
 
  instances:
  - name: cp4waiops-aimanager
    kind: AIManager
    install: true
  ...
```

### AIOPS main properties

The following properties are defined on the project level:

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| project                         | The name of the OpenShift project that will be created and used for the installation of the defined instances. | Yes  | |
| openshift_cluster_name          | Dynamically defined form the `env_id` parameter during the execution. | No, only if mutiple OpenShift clusters defined | Existing `openshift` cluster |
| openshift_storage_name          | Reference to the storage definition that exists in the `openshift` object (please see above). | No, inferred from openshift->openshift_storage | |
| accept_licenses | Set to `True` to accept Cloud Pak licenses. Alternatively the `--accept-all-licenses` can be used for the `cp-deploy.sh` command | Yes | True, False |

### Service instances

The project that is specified at the `cp4waiops` level defines the OpenShift project into which the instances of each of the services will be installed. Below is a list of instance "kinds" that can be installed. For every "service instance" there can also be a "demo content" entry to prepare the demo content for the capability.

### AI Manager

```yaml
  instances:
  - name: cp4waiops-aimanager
    kind: AIManager
    install: true

    waiops_size: small
    custom_size_file: none
    waiops_name: ibm-cp-watson-aiops
    subscription_channel: v3.6
    freeze_catalog: false
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | AIManager      |
| install             | Must the service be installed? | Yes | true, false |
| waiops_size         | Size of the install            | Yes | small, tall, custom |
| custom_size_file    | Name of the file holding the custom sizes if `waiops_size` is `custom` | No | |
| waiops_name         | Name of the CP4WAIOPS instance | Yes | |
| subscription_channel | Subscription channel of the operator | Yes | |
| freeze_catalog      | Freeze the version of the catalog source? | Yes | false, true |
| case_install        | Must AI manager be installed via case files? | No | false, true |
| case_github_url     | GitHub URL to download case file | Yes if `case_install` is `true` | |
| case_name           | Name of the case file          | Yes if `case_install` is `true` | |
| case_version        | Version of the case file to download | Yes if `case_install` is `true` | |
| case_inventory_setup | Case file operation to run for this service | Yes if `case_install` is `true` | cpwaiopsSetup |

### AI Manager - Demo Content

```yaml
  instances:
  - name: cp4waiops-aimanager-demo-content
    kind: AIManagerDemoContent
    install: true
    ...
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | AIManagerDemoContent      |
| install             | Must the content be installed? | Yes | true, false |

See sample config for remainder of properties.

### Event Manager

```yaml
  instances:
  - name: cp4waiops-eventmanager
    kind: EventManager
    install: true
    subscription_channel: v1.11
    starting_csv: noi.v1.7.0
    noi_version: 1.6.6
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | EventManager      |
| install             | Must the service be installed? | Yes | true, false |
| subscription_channel | Subscription channel of the operator | Yes | |
| starting_csv        | Starting Cluster Server Version | Yes | |
| noi_version         | Version of noi | Yes | |

### Event Manager Demo Content

```yaml
  instances:
  - name: cp4waiops-eventmanager
    kind: EventManagerDemoContent
    install: true
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | EventManagerDemoContent     |
| install             | Must the content be installed? | Yes | true, false |

### Infrastructure Management

```yaml
  instances:
  - name: cp4waiops-infrastructure-management
    kind: InfrastructureManagement
    install: false
    subscription_channel: v3.5
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | InfrastructureManagement      |
| install             | Must the service be installed? | Yes | true, false |
| subscription_channel | Subscription channel of the operator | Yes | |

### ELK stack

ElasticSearch, Logstash and Kibana stack.

```yaml
  instances:
  - name: cp4waiops-elk
    kind: ELK
    install: false
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | ELK      |
| install             | Must the service be installed? | Yes | true, false |

### Instana

```yaml
  instances:
  - name: cp4waiops-instana
    kind: Instana
    install: true
    version: 241-0

    sales_key: 'NONE'
    agent_key: 'NONE'

    instana_admin_user: "admin@instana.local"
    #instana_admin_pass: 'P4ssw0rd!'
    
    install_agent: true

    integrate_aimanager: true
    #integrate_turbonomic: true
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | Instana      |
| install             | Must the service be installed? | Yes | true, false |
| version             | Version of Instana to install | No | |
| sales_key           | License key to be configured   | No | |
| agent_key           | License key for agent to be configured   | No | |
| instana_admin_user  | Instana admin user to be configured | Yes | |
| instana_admin_pass  | Instana admin user password to be set (if different from global password) | No | |
| install_agent       | Must the Instana agent be installed? | Yes | true, false |
| integrate_aimanager | Must Instana be integrated with AI Manager? | Yes | true, false |
| integrate_turbonomic | Must Instana be integrated with Turbonomic? | No | true, false |

### Turbonomic

```yaml
  instances:
  - name: cp4waiops-turbonomic
    kind: Turbonomic
    install: true
    turbo_version: 8.7.0
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | Turbonomic      |
| install             | Must the service be installed? | Yes | true, false |
| turbo_version       | Version of Turbonomic to install | Yes | |

### Turbonomic Demo Content

```yaml
  instances:
  - name: cp4waiops-turbonomic-demo-content
    kind: TurbonomicDemoContent
    install: true
    #turbo_admin_password: P4ssw0rd!
    create_user: false
    demo_user: demo
    #turbo_demo_password: P4ssw0rd!
```

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| name                | Unique name within the cluster using only lowercase alphanumerics and "-" | Yes | |
| kind                | Service kind to install        | Yes       | TurbonomicDemoContent     |
| install             | Must the content be installed? | Yes | true, false |
| turbo_admin_pass    | Turbonomic admin user password to be set (if different from global password) | No | |
| create_user         | Must the demo user be created? | No | false, true |
| demo_user           | Name of the demo user | No | |
| turbo_demo_password | Demo user password if different from global password | No | |

See sample config for remainder of properties.

## `cp4ba`

Defines the Cloud Pak for Business Automation installation to be configured on the OpenShift cluster(s).  
See [Cloud Pak for Business Automation](../../../30-reference/configuration/cp4ba) for additional details.  

```yaml
---
cp4ba:
- project: cp4ba
  collateral_project: cp4ba-collateral
  openshift_cluster_name: "{{ env_id }}"
  openshift_storage_name: auto-storage
  accept_licenses: false
  state: installed
  cpfs_profile_size: small # Profile size which affect replicas and resources of Pods of CPFS as per https://www.ibm.com/docs/en/cpfs?topic=operator-hardware-requirements-recommendations-foundational-services

  # Section for Cloud Pak for Business Automation itself
  cp4ba:
    # Set to false if you don't want to install (or remove) CP4BA
    enabled: true # Currently always true
    profile_size: small # Profile size which affect replicas and resources of Pods as per https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=pcmppd-system-requirements
    patterns:
      foundation: # Foundation pattern, always true - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__foundation
        optional_components:
          bas: true # Business Automation Studio (BAS) 
          bai: true # Business Automation Insights (BAI)
          ae: true # Application Engine (AE)
      decisions: # Operational Decision Manager (ODM) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__odm
        enabled: true
        optional_components:
          decision_center: true # Decision Center (ODM)
          decision_runner: true # Decision Runner (ODM)
          decision_server_runtime: true # Decision Server (ODM)
        # Additional customization for Operational Decision Management
        # Contents of the following will be merged into ODM part of CP4BA CR yaml file. Arrays are overwritten.
        cr_custom:
          spec:
            odm_configuration:
              decisionCenter:
                # Enable support for decision models
                disabledDecisionModel: false
      decisions_ads: # Automation Decision Services (ADS) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__ads
        enabled: true
        optional_components:
          ads_designer: true # Designer (ADS)
          ads_runtime: true # Runtime (ADS)
      content: # FileNet Content Manager (FNCM) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__ecm
        enabled: true
        optional_components:
          cmis: true # Content Management Interoperability Services (FNCM - CMIS)
          css: true # Content Search Services (FNCM - CSS)
          es: true # External Share (FNCM - ES)
          tm: true # Task Manager (FNCM - TM)
          ier: true # IBM Enterprise Records (FNCM - IER)
          icc4sap: false # IBM Content Collector for SAP (FNCM - ICC4SAP) - Currently not implemented
      application: # Business Automation Application (BAA) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__baa
        enabled: true
        optional_components:
          app_designer: true # App Designer (BAA)
          ae_data_persistence: true # App Engine data persistence (BAA)
      document_processing: # Automation Document Processing (ADP) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__adp
        enabled: true
        optional_components: 
          document_processing_designer: true # Designer (ADP)
        # Additional customization for Automation Document Processing
        # Contents of the following will be merged into ADP part of CP4BA CR yaml file. Arrays are overwritten.
        cr_custom:
          spec:
            ca_configuration:
              ## NB: All config parameters for ADP are described here ==> https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=parameters-automation-document-processing
              ocrextraction:
                # [Tech Preview] OCR Engine 2 (IOCR) for ADP - Starts the Watson Document Understanding (WDU) pods to process documents.
                use_iocr: auto # Allowed values: auto, all, none. Refer to doc for option details: https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=parameters-automation-document-processing#:~:text=ocrextraction.use_iocr
                deep_learning_object_detection: # When enabled, ca_configuration.deeplearning parameters will be used (ignored otherwise), and deep-learning pods will be deployed to enhance object detection.
                  # If disabled, all training will automatically be done in "fast-training" mode and should finish in less than 10 min.
                  # Warn: If you enable this option and don't select the "fast training" mode in ADP before starting training, training could take hours (or more if you don't have GPUs).
                  #       See "Important" note here for usage recommandation on using "fast/deeplarning" training: https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/23.0.2?topic=project-creating-data-extraction-model#:~:text=Training%20takes%20time
                  enabled: true
              deeplearning: # Only used if deep_learning_object_detection is enabled. Configure usage of GPU-enabled Nodes.
                gpu_enabled: false # Use GPUs for deeplearning training instead of CPUs.
                nodelabel_key: nvidia.com/gpu.present
                nodelabel_value: "true"
                replica_count: 1 # Controls the number of deep learning pod replicas. NB: The number of GPUs available on your cluster should be ≥ to replica_count.
      workflow: # Business Automation Workflow (BAW) - https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__baw
        enabled: true
        optional_components:
          baw_authoring: true # Workflow Authoring (BAW) - always keep true if workflow pattern is chosen. BAW Runtime is not implemented.
          kafka: true # Will install a kafka cluster and enable kafka service for workflow authoring.
  
  # Section for IBM Process mining
  pm:
    # Set to false if you don't want to install (or remove) Process Mining
    enabled: true
    # Additional customization for Process Mining
    # Contents of the following will be merged into PM CR yaml file. Arrays are overwritten.
    cr_custom:
      spec:
        processmining:
          storage:
            # Disables redis to spare resources as per https://www.ibm.com/docs/en/process-mining/latest?topic=configurations-custom-resource-definition
            redis:
              install: false  

  # Section for IBM Robotic Process Automation
  rpa:
    # Set to false if you don't want to install (or remove) RPA
    enabled: true
    # Additional customization for Robotic Process Automation
    # Contents of the following will be merged into RPA CR yaml file. Arrays are overwritten.
    cr_custom:
      spec:
        # Configures the NLP provider component of IBM RPA. You can disable it by specifying 0. https://www.ibm.com/docs/en/rpa/latest?topic=platform-configuring-rpa-custom-resources#basic-setup
        nlp:
          replicas: 1

  # Set to false if you don't want to install (or remove) CloudBeaver (PostgreSQL, DB2, MSSQL UI)
  cloudbeaver_enabled: true

  # Set to false if you don't want to install (or remove) Roundcube
  roundcube_enabled: true

  # Set to false if you don't want to install (or remove) Cerebro
  cerebro_enabled: true

  # Set to false if you don't want to install (or remove) AKHQ
  akhq_enabled: true

  # Set to false if you don't want to install (or remove) Mongo Express
  mongo_express_enabled: true

  # Set to false if you don't want to install (or remove) phpLDAPAdmin
  phpldapadmin_enabled: true

  # Set to false if you don't want to install (or remove) OpenSearch Dashboards
  opensearch_dashboards_enabled: true  
```

### CP4BA main properties

The following properties are defined on the project level.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| project                         | The name of the OpenShift project that will be created and used for the installation of the defined instances. | Yes  | Valid OCP project name |
| collateral_project              | The name of the OpenShift project that will be created and used for the installation of all collateral (prerequisites and extras). | Yes  | Valid OCP project name |
| openshift_cluster_name          | Dynamically defined form the `env_id` parameter during the execution. | No, only if multiple OpenShift clusters defined | Existing `openshift` cluster |
| openshift_storage_name          | Reference to the storage definition that exists in the `openshift` object (please see above). | No, inferred from openshift->openshift_storage | |
| accept_licenses | Set to `true` to accept Cloud Pak licenses. Alternatively the `--accept-all-licenses` can be used for the `cp-deploy.sh` command | Yes | true, false |
| state | Set to `installed` to install `enabled` capabilities, set to `removed` to remove `enabled` capabilities. | Yes | installed, removed |
| cpfs_profile_size                         | Profile size which affect replicas and resources of Pods of CPFS as per <https://www.ibm.com/docs/en/cpfs?topic=operator-hardware-requirements-recommendations-foundational-services> | Yes  | starterset, small, medium, large |

### Cloud Pak for Business Automation properties

Used to configure CP4BA.  
Placed in `cp4ba` key on the project level.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable CP4BA. Currently always `true`. | Yes  | true |
| profile_size                         | Profile size which affect replicas and resources of Pods as per <https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=pcmppd-system-requirements> | Yes  | small, medium, large |
| patterns          | Section where CP4BA patterns are configured. Please make sure to select all that is needed as a dependencies. Dependencies can be determined from documentation at <https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments> | Yes | Object - see details below |

#### Foundation pattern properties

Always configure in CP4BA.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__foundation>  
Placed in `cp4ba.patterns.foundation` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.bas          | Set to `true` to enable Business Automation Studio | Yes | true, false |
| optional_components.bai          | Set to `true` to enable Business Automation Insights | Yes | true, false |
| optional_components.ae          | Set to `true` to enable Application Engine | Yes | true, false |

#### Decisions pattern properties

Used to configure Operation Decision Manager.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__odm>  
Placed in `cp4ba.patterns.decisions` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `decisions` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.decision_center          | Set to `true` to enable Decision Center | Yes | true, false |
| optional_components.decision_runner          | Set to `true` to enable Decision Runner | Yes | true, false |
| optional_components.decision_server_runtime          | Set to `true` to enable Decision Server | Yes | true, false |
| cr_custom          | Additional customization for Operational Decision Management. Contents will be merged into ODM part of CP4BA CR yaml file. Arrays are overwritten. | No | Object |

#### Decisions ADS pattern properties

Used to configure Automation Decision Services.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__ads>  
Placed in `cp4ba.patterns.decisions_ads` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `decisions_ads` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.ads_designer          | Set to `true` to enable Designer | Yes | true, false |
| optional_components.ads_runtime          | Set to `true` to enable Runtime | Yes | true, false |

#### Content pattern properties

Used to configure FileNet Content Manager.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__ecm>  
Placed in `cp4ba.patterns.content` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `content` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.cmis          | Set to `true` to enable CMIS | Yes | true, false |
| optional_components.css          | Set to `true` to enable Content Search Services | Yes | true, false |
| optional_components.es          | Set to `true` to enable External Share. Currently not functional. | Yes | true, false |
| optional_components.tm          | Set to `true` to enable Task Manager | Yes | true, false |
| optional_components.ier          | Set to `true` to enable IBM Enterprise Records | Yes | true, false |
| optional_components.icc4sap          | Set to `true` to enable IBM Content Collector for SAP. Currently not functional. Always false. | Yes | false |

#### Application pattern properties

Used to configure Business Automation Application.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__baa>  
Placed in `cp4ba.patterns.application` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `application` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.app_designer          | Set to `true` to enable Application Designer | Yes | true, false |
| optional_components.ae_data_persistence          | Set to `true` to enable App Engine data persistence | Yes | true, false |

#### Document Processing pattern properties

Used to configure Automation Document Processing.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__baa>  
Placed in `cp4ba.patterns.document_processing` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `document_processing` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.document_processing_designer          | Set to `true` to enable Designer | Yes | true |
| cr_custom          | Additional customization for Automation Document Processing. Contents will be merged into ADP part of CP4BA CR yaml file. Arrays are overwritten. | No | Object |

#### Workflow pattern properties

Used to configure Business Automation Workflow.  
<https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/latest?topic=deployment-capabilities-production-deployments#concept_c2l_1ks_fnb__baw>  
Placed in `cp4ba.patterns.workflow` key.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `workflow` pattern. | Yes  | true, false |
| optional_components                         | Sub object for definition of optional components for pattern. | Yes  | Object - specific to each pattern |
| optional_components.baw_authoring          | Set to `true` to enable Workflow Authoring. Currently always `true`. | Yes | true |
| optional_components.kafka          | Set to `true` to install a kafka cluster and enable kafka service for workflow authoring. | Yes | true, false |

### Process Mining properties

Used to configure IBM Process Mining.  
Placed in `pm` key on the project level.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `process mining`. | Yes  | true, false |
| cr_custom          | Additional customization for Process Mining. Contents will be merged into PM CR yaml file. Arrays are overwritten. | No | Object |

### Robotic Process Automation properties

Used to configure IBM Robotic Process Automation.  
Placed in `rpa` key on the project level.

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| enabled                         | Set to `true` to enable `rpa`. | Yes  | true, false |
| cr_custom          | Additional customization for Process Mining. Contents will be merged into RPA CR yaml file. Arrays are overwritten. | No | Object |

### Other properties

Used to configure extra UIs.  
The following properties are defined on the project level.  

| Property            | Description                    | Mandatory            | Allowed values |
|---------------------|--------------------------------|----------------------|----------------|
| cloudbeaver_enabled                         | Set to `true` to enable CloudBeaver (PostgreSQL, DB2, MSSQL UI). | Yes  | true, false |
| roundcube_enabled                         | Set to `true` to enable Roundcube. Client for mail. | Yes  | true, false |
| cerebro_enabled                         | Set to `true` to enable Cerebro. Client for ElasticSearch in CP4BA. | Yes  | true, false |
| akhq_enabled                         | Set to `true` to enable AKHQ. Client for Kafka in CP4BA. | Yes  | true, false |
| mongo_express_enabled                         | Set to `true` to enable Mongo Express. Client for MongoDB. | Yes  | true, false |
| phpldapadmin_enabled                         | Set to `true` to enable phpLDApAdmin. Client for OpenLDAP. | Yes  | true, false |
| opensearch_dashboards_enabled                         | Set to `true` to enable OpenSearch Dashboards. Client for OpenSearch. | Yes  | true, false |
