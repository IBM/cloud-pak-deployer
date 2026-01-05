# Running deployer on OpenShift using console

See the deployer in action deploying IBM watsonx.ai on an existing OpenShift cluster in this video:

<video src="https://ibm.box.com/shared/static/iabmg861w5eiz30pwh4ph2chlv2m1k6q.mp4" controls="controls" muted="muted" class="d-block rounded-bottom-2 border-top width-fit" style="max-height:300px; min-height: 200px"></video>

## Log in to the OpenShift cluster
Log in as a cluster administrator to be able to run the deployer with the correct permissions.

## TechZone clusters and Watson Studio Pipelines (Pipeline Orchestration)

!!! warning "OpenShift Pipelines must be removed manually"
    The Watson Studio Pipelines cartridge (also referred to as Pipeline Orchestration) installs its own Tekton controllers.  
    TechZone OpenShift clusters already include the Red Hat OpenShift Pipelines operator that owns the same Tekton
    resources, so the install fails if both are present. The Cloud Pak Deployer does **not** uninstall shared cluster
    components. Remove OpenShift Pipelines yourself **before** you add `ws-pipelines` to the configuration.

Follow these steps once per cluster:

1. Sign in to the OpenShift web console with a cluster-admin user.
2. Go to `Operators` → `Installed Operators`, open **OpenShift Pipelines** (namespace `openshift-operators`), choose **Actions → Uninstall**, keep *Delete operand resources* selected, and confirm.
3. Wait until the operator disappears from the list and the `openshift-pipelines-operator` CSV is removed.
4. Verify that no `TektonConfig` instance is left. The following command should return *No resources found*:
   ```bash
   oc get tektonconfig
   ```
5. If a `tekton-pipelines` project still exists, delete it to remove the remaining webhooks.

TechZone automation itself runs on OpenShift Pipelines, so uninstalling it stops the TechZone pipeline that would normally start the deployer. After completing the above steps, start the deployer directly from the OpenShift console (as described below). You can reinstall OpenShift Pipelines from OperatorHub again after Watson Studio Pipelines has been successfully deployed.

## Prepare the deployer project
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
???+ note "Prepare the deployer project"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      creationTimestamp: null
      name: cloud-pak-deployer
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: cloud-pak-deployer-sa
      namespace: cloud-pak-deployer
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: system:openshift:scc:privileged
      namespace: cloud-pak-deployer
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: system:openshift:scc:privileged
    subjects:
    - kind: ServiceAccount
      name: cloud-pak-deployer-sa
      namespace: cloud-pak-deployer
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: cloud-pak-deployer-cluster-admin
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: cloud-pak-deployer-sa
      namespace: cloud-pak-deployer
    ```

## Set the entitlement key
* Update the secret below with your container software Entitlement key from https://myibm.ibm.com/products-services/containerlibrary. Make sure the key is indented exactly as below.
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block with **replaced YOUR_ENTITLEMENT_KEY** on line 10
???+ note "Set the entitlement key"
    ``` { .yaml .copy linenums="1" hl_lines="10" }
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: cloud-pak-entitlement-key
      namespace: cloud-pak-deployer
    type: Opaque
    stringData:
      cp-entitlement-key: |
        YOUR_ENTITLEMENT_KEY
    ```

## Configure the Cloud Paks and services to be deployed
* Update the configuration below to match what you want to deploy, do not change indent
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the below block (exactly into the window)
* Update the `cp4d` element and select the version and cartridges you want to install

!!! info
    The below is an example of a Software Hub installation. Other example configurations:
    
    * [Software Hub with Keycloak as the identity provider](./existing-openshift-software-hub-keycloak.md){target="_blank}
    * [Software Hub watsonx.ai](./existing-openshift-software-hub-watsonx-ai.md){target="_blank}


???+ note "Sample CP4D configuration"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cloud-pak-deployer-config
      namespace: cloud-pak-deployer
    data:
      cpd-config.yaml: |
        global_config:
          environment_name: demo
          cloud_platform: existing-ocp
          confirm_destroy: False
          optimize_deploy: True
          env_id: cpd-demo

        openshift:
        - name: "{{ env_id }}"
          ocp_version: "4.16"
          cluster_name: "{{ env_id }}"
          domain_name: example.com
          mcg:
            install: False
            storage_type: storage-class
            storage_class: managed-nfs-storage
          gpu:
            install: auto
          openshift_ai:
            install: auto
            channel: auto
          openshift_storage:
          - storage_name: auto-storage
            storage_type: auto

        cp4d:
        - project: cpd
          openshift_cluster_name: "{{ env_id }}"
          cp4d_version: latest
          cp4d_entitlement: 
          - cpd-enterprise
          # - cpd-standard
          # - cognos-analytics
          # - data-product-hub
          # - datastage
          # - ikc-premium
          # - ikc-standard
          # - openpages
          # - planning-analytics
          # - product-master
          # - speech-to-text
          # - text-to-speech
          # - watson-assistant
          # - watson-discovery
          # - watsonx-ai
          # - watsonx-code-assistant-ansible
          # - watsonx-code-assistant-z
          # - watsonx-data
          # - watsonx-gov-mm
          # - watsonx-gov-rc
          # - watsonx-orchestrate
          cp4d_production_license: True
          accept_licenses: False
          db2u_limited_privileges: False
          operators_project: cpd-operators
          ibm_cert_manager: False
          install_day0_patch: True
          state: installed
          cartridges:
          - name: cp-foundation
            scale: level_1
            license_service:
              threads_per_core: 2
          
          - name: lite

          - name: scheduler 
            state: removed
            
        #
        # All tested cartridges. To install, change the "state" property to "installed". To uninstall, change the state
        # to "removed" or comment out the entire cartridge. Make sure that the "-" and properties are aligned with the lite
        # cartridge; the "-" is at position 3 and the property starts at position 5.
        #
        # If a cartridge has dependencies and you want to install it, you must ensure that the dependent cartridge is also
        # installed.
        #

          - name: analyticsengine 
            description: Analytics Engine Powered by Apache Spark 
            size: small 
            state: removed
            installation_options:
              sparkAdvEnabled: true
              jobAutoDeleteEnabled: true
              kernelCullTime: 30
              imagePullParallelism: "40"
              imagePullCompletions: "20"
              kernelCleanupSchedule: "*/30 * * * *"
              jobCleanupSchedule: "*/30 * * * *"
              skipSelinuxRelabeling: false
              mountCustomizationsFromCchome: false
              maxDriverCpuCores: 5
              maxExecutorCpuCores: 5
              maxDriveMemory: "50g"
              maxExecutorMemory: "50g"
              maxNumWorkers: 50
              localDirScaleFactor: 10

          - name: bigsql
            description: Db2 Big SQL
            state: removed

          - name: ca
            description: Cognos Analytics
            size: small
            instances:
            - name: ca-instance
              metastore_ref: ca-metastore
            state: removed

          - name: dashboard
            description: Cognos Dashboards
            state: removed

          - name: datagate
            description: Db2 Data Gate
            state: removed

          - name: datalineage
            description: IBM MANTA Data Lineage
            size: small
            state: removed

          - name: dataproduct
            description: Data Product Hub
            state: removed
            
          - name: datastage-ent
            description: DataStage Enterprise
            state: removed

          - name: datastage-ent-plus
            description: DataStage Enterprise Plus
            state: removed
            # instances:
            #   - name: ds-instance
            #     # Optional settings
            #     description: "datastage ds-instance"
            #     size: medium
            #     storage_class: efs-nfs-client
            #     storage_size_gb: 60
            #     # Custom Scale options
            #     scale_px_runtime:
            #       replicas: 2
            #       cpu_request: 500m
            #       cpu_limit: 2
            #       memory_request: 2Gi
            #       memory_limit: 4Gi
            #     scale_px_compute:
            #       replicas: 2
            #       cpu_request: 1
            #       cpu_limit: 3
            #       memory_request: 4Gi
            #       memory_limit: 12Gi    

          - name: db2
            description: Db2 OLTP
            size: small
            instances:
            - name: ca-metastore
              metadata_size_gb: 20
              data_size_gb: 20
              backup_size_gb: 20  
              transactionlog_size_gb: 20
            state: removed

          - name: db2wh
            description: Db2 Warehouse
            state: removed

          - name: dmc
            description: Db2 Data Management Console
            state: removed
            instances:
            - name: data-management-console
              description: Data Management Console
              size: medium
              storage_size_gb: 50

          - name: dods
            description: Decision Optimization
            size: small
            state: removed

          - name: dp
            description: Data Privacy
            size: small
            state: removed

          - name: dpra
            description: Data Privacy Risk Assessment
            state: removed

          - name: dv
            description: Data Virtualization
            size: small 
            instances:
            - name: data-virtualization
            state: removed

          # Please note that for EDB Postgress, a secret edb-postgres-license-key must be created in the vault
          # before deploying
          - name: edb_cp4d
            description: EDB Postgres
            state: removed
            instances:
            - name: instance1
              version: "15.4"
              #type: Standard
              #members: 1
              #size_gb: 50
              #resource_request_cpu: 1
              #resource_request_memory: 4Gi
              #resource_limit_cpu: 1
              #resource_limit_memory: 4Gi

          - name: factsheet
            description: AI Factsheets
            size: small
            state: removed

          - name: hee
            description: Execution Engine for Apache Hadoop
            size: small
            state: removed

          - name: mantaflow
            description: MANTA Automated Lineage
            size: small
            state: removed

          - name: match360
            description: IBM Match 360
            state: removed
            installation_options:
              scaleConfig: x-small
              onboard_timeout: 300
              ccs_http_timeout: 2000

          - name: mongodb
            description: MongoDB for Cloud Pak for Data
            state: removed
            
          - name: openpages
            description: OpenPages
            state: removed

          - name: planning-analytics
            description: Planning Analytics
            state: removed
            instances:
            - name: pa-instance
              size: small
              mysql_size_gb: 20
              couchdb_size_gb: 20
              mongo_size_gb: 20
              redis_size_gb: 20

          - name: replication
            description: Data Replication
            size: small
            state: removed
            installation_options:
              replication_license_type: IDRC    

          - name: rstudio
            description: RStudio Server with R 3.6
            size: small
            state: removed

          - name: spss
            description: SPSS Modeler
            state: removed

          - name: streamsets
            description: IBM StreamSets
            state: removed

          - name: syntheticdata
            description: Synthetic Data Generator
            state: removed

          - name: udp
            description: Data Integration for Unstructured Data
            state: removed

          - name: voice-gateway
            description: Voice Gateway
            replicas: 1
            state: removed

          # In case watsonx Orchestrate is installed, Watson Assistant should not be explicitly set to installed
          - name: watson-assistant
            description: Watson Assistant
            size: small
            # noobaa_account_secret: noobaa-admin
            # noobaa_cert_secret: noobaa-s3-serving-cert
            state: removed
            # instances:
            # - name: wa-instance
            #   description: "Watson Assistant instance"
            installation_options:
              size: Production
              bigpv: false
              analytics: true
              watsonxAiType: embedded
              syomModels: []
              ootbModels: []

          - name: watson-discovery
            description: Watson Discovery
            # noobaa_account_secret: noobaa-admin
            # noobaa_cert_secret: noobaa-s3-serving-cert
            state: removed
            instances:
            - name: wd-instance
              description: "Watson Discovery instance"
            installation_options:
              discovery_deployment_type: Production

          - name: watson-openscale
            description: Watson OpenScale
            size: small
            state: removed

          - name: watson-speech
            description: Watson Speech (STT and TTS)
            stt_size: xsmall
            tts_size: xsmall
            # noobaa_account_secret: noobaa-admin
            # noobaa_cert_secret: noobaa-s3-serving-cert
            state: removed
            installation_options:
              tags:
                sttRuntime: true
                sttAsync: false
                sttCustomization: false
                ttsRuntime: true
                ttsCustomization: false
              scaleConfig:
                stt:
                  size: xsmall
                tts:
                  size: xsmall
              sttModels:
              - enUsBroadbandModel
              - enUsNarrowbandModel
              - enUsShortFormNarrowbandModel
              - enUsTelephony
              - enUsMultimedia
              ttsVoices:
              - enUSAllisonV3Voice
              - enUSLisaV3Voice
              - enUSMichaelV3Voice

          - name: watsonx_ai
            description: watsonx.ai
            state: removed
            installation_options:
              tuning_disabled: true
              liteInstall: false
            models:
            - model_id: allam-1-13b-instruct
              state: removed
              # model_install_parameters can be used for sharding and node pinning according to
              # instructions at https://www.ibm.com/docs/en/software-hub/5.3.x?topic=setup-adding-foundation-models
              #model_install_parameters:
              #  shards: 2
              #  nodeSelector:
              #    kubernetes.io/hostname: hostname
            - model_id: codellama-codellama-34b-instruct-hf
              state: removed
            - model_id: codestral-2501
              state: removed
            - model_id: codestral-2508
              state: removed
            - model_id: codestral-22b
              state: removed
            - model_id: devstral-medium-2507
              state: removed
            - model_id: google-flan-t5-xl
              state: removed
            - model_id: gpt-oss-20b
              state: removed
            - model_id: gpt-oss-120b
              state: removed
            - model_id: granite-4-h-micro
              state: removed
            - model_id: granite-4-h-tiny
              state: removed
            - model_id: granite-4-h-small
              state: removed
            - model_id: ibm-granite-13b-instruct-v2
              state: removed
            - model_id: granite-3-2-8b-instruct
              state: removed
            - model_id: granite-3-3-8b-instruct
              state: removed
            - model_id: granite-3-2b-instruct
              state: removed
            - model_id: granite-3-8b-instruct
              state: removed
            - model_id: granite-guardian-3-2b
              state: removed
            - model_id: granite-guardian-3-8b
              state: removed
            - model_id: granite-guardian-3-2-5b
              state: removed
            - model_id: granite-3b-code-instruct
              state: removed
            - model_id: granite-8b-code-instruct
              state: removed
            - model_id: granite-20b-code-instruct
              state: removed
            - model_id: granite-20b-code-base-schema-linking
              state: removed
            - model_id: granite-20b-code-base-sql-gen
              state: removed
            - model_id: granite-34b-code-instruct
              state: removed
            - model_id: granite-docling-258M
              state: removed
            - model_id: granite-vision-3-2-2b
              state: removed
            - model_id: granite-vision-3-3-2b
              state: removed
            - model_id: ibm-defense-3-3-8b-instruct
              state: removed
            - model_id: ibm-defense-4-0-micro
              state: removed
            - model_id: core42-jais-13b-chat
              state: removed
            - model_id: llama-3-2-1b-instruct
              state: removed
            - model_id: llama-4-maverick-17b-128e-instruct-fp8
              state: removed
            - model_id: llama-4-maverick-17b-128e-instruct-int4
              state: removed
            - model_id: llama-4-scout-17b-16e-instruct
              state: removed
            - model_id: llama-4-scout-17b-16e-instruct-int4
              state: removed
            - model_id: llama-3-3-70b-instruct
              state: removed
            - model_id: llama-3-2-1b-instruct
              state: removed
            - model_id: llama-3-2-3b-instruct
              state: removed
            - model_id: llama-3-2-11b-vision-instruct
              state: removed
            - model_id: llama-3-2-90b-vision-instruct
              state: removed
            - model_id: llama-guard-3-11b-vision
              state: removed
            - model_id: llama-3-1-8b-instruct
              state: removed
            - model_id: llama-3-1-70b-instruct
              state: removed
            - model_id: ministral-8b-instruct
              state: removed
            - model_id: mistral-small-3-2-24b-instruct-2506
              state: removed
            - model_id: mistral-small-3-1-24b-instruct-2503
              state: removed
            - model_id: mistral-medium-2505
              state: removed
            - model_id: mistral-medium-2508
              state: removed
            - model_id: mistral-large-instruct-2411
              state: removed
            - model_id: pixtral-large-instruct
              state: removed
            - model_id: voxtral-small-2507
              state: removed
            # Embedding models
            - model_id: all-minilm-l6-v2
              state: removed
            - model_id: all-minilm-l12-v2
              state: removed
            - model_id: granite-embedding-107m-multilingual
              state: removed
            - model_id: granite-embedding-278m-multilingual
              state: removed
            - model_id: granite-embedding-english-reranker-r2
              state: removed
            - model_id: multilingual-e5-large
              state: removed
            - model_id: ibm-slate-30m-english-rtrvr
              state: removed
            - model_id: ibm-slate-125m-english-rtrvr
              state: removed
            - model_id: ms-marco-minilm-l-12-v2
              state: removed

          - name: watsonx_data
            description: watsonx.data
            state: removed
            installation_options:
              enable_lite_milvus: false
              scaleConfig: small    

          - name: watsonx_dataintegration
            description: watsonx.data integration
            state: removed
            installation_options:
              enableBatchBulkETL: true
              enableRealtimeStreaming: true
              enableDataObservability: true
              enableUnstructuredDataIntegration: true
              enableReplication: true

          - name: watsonx_dataintelligence
            description: watsonx.data intelligence
            state: removed
            installation_options:
              enableAISearch: false
              enableContentLinkingForTextToSql: false
              enableDataGovernanceCatalog: true
              enableDataLineage: true
              enableDataProduct: true
              enableDataQuality: false
              enableGenerativeAICapabilities: true
              enableKnowledgeGraph: true
              enableModelsOn: cpu
              enableSemanticEmbedding: false
              enableSemanticEnrichment: true
              enableTextToSql: false

          - name: watsonx_data_premium
            description: watsonx.data Premium
            state: removed
            installation_options:
              wxd_premium_enable_models_on: gpu
              licenseType: premium

          - name: watsonx_governance
            description: watsonx.governance
            state: removed
            installation_options:
              installType: all
              enableFactsheet: true
              enableOpenpages: true
              enableOpenscale: true

          - name: watsonx_orchestrate
            description: watsonx.orchestrate
            state: removed
            instances:
            - name: wxo-instance
              description: "watsonx Orchestrate instance"
            installation_options:
              installMode: "agentic"  
              watsonxAI:
                watsonxaiifm: true
                syomModels: []
                ootbModels: []

          - name: wca-ansible
            description: watsxonx Code Assistant for Red Hat Ansible Lightspeed
            state: removed

          - name: wca-z
            description: watsxonx Code Assistant for Z
            state: removed

          - name: wca-z-ce
            description: watsxonx Code Assistant for Z Code Explanation
            state: removed

          - name: wkc
            description: IBM Knowledge Catalog
            size: small
            state: removed
            installation_options:
              enableKnowledgeGraph: False
              enableDataQuality: False
              useFDB: False

          - name: ikc_premium
            description: IBM Knowledge Catalog - Premium edition
            size: small
            state: removed
            installation_options:
              enableDataQuality: False
              enableKnowledgeGraph: False
              useFDB: False
              enableAISearch: False
              enableSemanticAutomation: False
              enableSemanticEnrichment: True
              enableSemanticEmbedding: False
              enableTextToSql: False
              enableModelsOn: 'cpu'
              customModelTextToSQL: granite-3-3-8b-instruct
              
          - name: ikc_standard
            description: IBM Knowledge Catalog - Standard edition
            size: small
            state: removed
            installation_options:
              enableKnowledgeGraph: False
              useFDB: False
              enableAISearch: False
              enableSemanticAutomation: False
              enableSemanticEnrichment: True
              enableSemanticEmbedding: False
              enableTextToSql: False
              enableModelsOn: 'cpu'
              customModelTextToSQL: granite-3-3-8b-instruct

          - name: wml
            description: Watson Machine Learning
            size: small
            state: removed

          - name: wml-accelerator
            description: Watson Machine Learning Accelerator
            replicas: 1
            size: small
            state: removed

          - name: ws
            description: Watson Studio
            state: removed

          - name: ws-pipelines
            description: Orchestrateion Pipelines
            state: removed
            installation_options:
              rbsimage: rbs-ext

          - name: ws-runtimes
            description: Watson Studio Runtimes
            state: removed 
            installation_options:
              kinds:
              - ibm-cpd-ws-runtime-241-pygpu
              - ibm-cpd-ws-runtime-251-pygpu
              - ibm-cpd-ws-runtime-241-r
              - ibm-cpd-ws-runtime-251-r

        #
        # Cartridges where extra work is needed (will not install automatically)
        # 
          # Product Master requires set up of the Db2 instance secret before install
          - name: productmaster
            description: Product Master
            size: small  
            state: removed
    ```

## Start the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job (From release v3.0.2 onwards).

!!! info
    The below starts the deployer apply process using the above configuration. Additionally, you can:
    
    * Start only the debug job and run the deployer in the debug pod. See [Start deployer debug job](./existing-openshift-console-debug-job.md){target="_blank}
    * Configure environment variables such as proxy server. See [Configure environment variables for proxy and other settings](./existing-openshift-environment-variables-and-proxy.md){target="_blank}

???+ note "Start the deployer"
    ``` { .yaml .copy linenums="1" hl_lines="11" }
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        app: cloud-pak-deployer-start
      generateName: cloud-pak-deployer-start-
      namespace: cloud-pak-deployer
    spec:
      containers:
      - name: cloud-pak-deployer
        image: quay.io/cloud-pak-deployer/cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        command: ["/bin/sh","-xc"]
        args: 
          - /cloud-pak-deployer/scripts/deployer/cpd-start-deployer.sh
        envFrom:
        - configMapRef:
            name: cloud-pak-deployer-env
            optional: true
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
    ```

## Follow the logs of the deployment
* Open the OpenShift console
* Go to Workloads --> Pods
* Select `cloud-pak-deployer` as the project at the top of the page
* Click the deployer Pod
* Click Logs tab

!!! info
    When running the deployer installing Cloud Pak for Data, the first run will fail. This is because the deployer applies the node configuration to OpenShift, which will cause all nodes to restart one by one, including the node that runs the deployer. Because of the Job setting, a new deployer pod will automatically start and resume from where it was stopped.  

## Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. 
```
--- Cloud Pak for Data project cpd ---
CP4D URL: https://cpd-cpd.apps.6759f8089266ae8f450d554f.ocp.techzone.ibm.com
CP4D User: cpadmin
CP4D cpadmin password: <your-cpadmin-password>
```

You can also find this information under the `cloud-paks` directory in the status directory you specified. The following commands can be run from the **debug** pod terminal that is in the `cloud-pak-deployer` project.

To retrieve the Cloud Pak URL(s):

``` { .bash .copy }
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd (domain name specified was example.com):
https://cpd-cpd.apps.pluto-01.example.com
```

The `admin` password can be retrieved from the vault as follows:

List the secrets in the vault:

``` { .bash .copy }
cp-deploy.sh vault list
```

This will show something similar to the following:

```output
Secret list for group sample:
- ibm_cp_entitlement_key
- oc-login
- cp4d_admin_cpd_demo
```

You can then retrieve the Cloud Pak for Data admin password like this:

``` { .bash .copy }
cp-deploy.sh vault get --vault-secret cp4d_admin_cpd_sample
```

```output
PLAY [Secrets] *****************************************************************
included: /cloud-pak-deployer/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```


Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. 
```
--- Cloud Pak for Data project cpd ---
CP4D URL: https://cpd-cpd.apps.6759f8089266ae8f450d554f.ocp.techzone.ibm.com
CP4D User: cpadmin
CP4D cpadmin password: <your-cpadmin-password>
```

## Re-run deployer when failed or if you want to update the configuration
If the deployer has failed or if you want to make changes to the configuration after the successful run, you can do the following:

* Open the OpenShift console
* Go to Workloads --> Jobs
* Check the logs of the `cloud-pak-deployer` job
* If needed, make changes to the `cloud-pak-deployer-config` Config Map by going to Workloads --> ConfigMaps
* [Re-run the deployer](#start-the-deployer)
