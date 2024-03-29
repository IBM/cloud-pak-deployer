# Running deployer on OpenShift using console

See the deployer in action deploying IBM watsonx.ai on an existing OpenShift cluster in this video: https://ibm.box.com/v/cpd-wxai-existing-ocp

## Log in to the OpenShift cluster
Log in as a cluster administrator to be able to run the deployer with the correct permissions.

## Prepare the deployer Project
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
```
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
* Paste the follliwng block with **replaced YOUR_ENTITLEMENT_KEY**
```
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
* Paste the follliwng block (exactly into the window)
```
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

    openshift:
    - name: cpd-demo
      ocp_version: "4.12"
      cluster_name: cpd-demo
      domain_name: example.com
      mcg:
        install: False
        storage_type: storage-class
        storage_class: managed-nfs-storage
      gpu:
        install: False
      openshift_storage:
      - storage_name: auto-storage
        storage_type: auto

    cp4d:
    - project: cpd
      openshift_cluster_name: cpd-demo
      cp4d_version: 4.8.1
      sequential_install: False
      accept_licenses: True
      cartridges:
      cartridges:
      - name: cp-foundation
        license_service:
          state: disabled
          threads_per_core: 2
      
      - name: lite

      - name: scheduler 
        state: removed
        
      - name: analyticsengine 
        description: Analytics Engine Powered by Apache Spark 
        size: small 
        state: removed

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

      - name: hadoop
        description: Execution Engine for Apache Hadoop
        size: small
        state: removed

      - name: mantaflow
        description: MANTA Automated Lineage
        size: small
        state: removed

      - name: match360
        description: IBM Match 360
        size: small
        wkc_enabled: true
        state: removed

      - name: openpages
        description: OpenPages
        state: removed

      # For Planning Analytics, the case version is needed due to defect in olm utils
      - name: planning-analytics
        description: Planning Analytics
        state: removed

      - name: replication
        description: Data Replication
        license: IDRC
        size: small
        state: removed

      - name: rstudio
        description: RStudio Server with R 3.6
        size: small
        state: removed

      - name: spss
        description: SPSS Modeler
        state: removed

      - name: voice-gateway
        description: Voice Gateway
        replicas: 1
        state: removed

      - name: watson-assistant
        description: Watson Assistant
        size: small
        # noobaa_account_secret: noobaa-admin
        # noobaa_cert_secret: noobaa-s3-serving-cert
        state: removed

      - name: watson-discovery
        description: Watson Discovery
        # noobaa_account_secret: noobaa-admin
        # noobaa_cert_secret: noobaa-s3-serving-cert
        state: removed

      - name: watson-ks
        description: Watson Knowledge Studio
        size: small
        # noobaa_account_secret: noobaa-admin
        # noobaa_cert_secret: noobaa-s3-serving-cert
        state: removed

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

      # Please note that for watsonx.ai foundation models, you neeed to install the
      # Node Feature Discovery and NVIDIA GPU operators. You can do so by setting the openshift.gpu.install property to True
      - name: watsonx_ai
        description: watsonx.ai
        state: removed
        models:
        - model_id: google-flan-t5-xxl
          state: removed
        - model_id: google-flan-ul2
          state: removed
        - model_id: eleutherai-gpt-neox-20b
          state: removed
        - model_id: ibm-granite-13b-chat-v1
          state: removed
        - model_id: ibm-granite-13b-instruct-v1
          state: removed
        - model_id: meta-llama-llama-2-70b-chat
          state: removed
        - model_id: ibm-mpt-7b-instruct2
          state: removed
        - model_id: bigscience-mt0-xxl
          state: removed
        - model_id: bigcode-starcoder
          state: removed

      - name: watsonx_data
        description: watsonx.data
        state: removed

      - name: wkc
        description: Watson Knowledge Catalog
        size: small
        state: removed
        installation_options:
          install_wkc_core_only: False
          enableKnowledgeGraph: False
          enableDataQuality: False
          enableFactSheet: False

      - name: wml
        description: Watson Machine Learning
        size: small
        state: installed

      - name: wml-accelerator
        description: Watson Machine Learning Accelerator
        replicas: 1
        size: small
        state: removed

      - name: ws
        description: Watson Studio
        state: installed

      - name: ws-pipelines
        description: Watson Studio Pipelines
        state: removed

      - name: ws-runtimes
        description: Watson Studio Runtimes
        runtimes:
        - ibm-cpd-ws-runtime-py39
        - ibm-cpd-ws-runtime-222-py
        - ibm-cpd-ws-runtime-py39gpu
        - ibm-cpd-ws-runtime-222-pygpu
        - ibm-cpd-ws-runtime-231-pygpu
        - ibm-cpd-ws-runtime-r36
        - ibm-cpd-ws-runtime-222-r
        - ibm-cpd-ws-runtime-231-r
        state: removed 
```

## Start the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
```
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

## Re-run deployer when failed or if you want to update the configuration
If the deployer has failed or if you want to make changes to the configuration after the successful run, you can do the following:

* Open the OpenShift console
* Go to Workloads --> Jobs
* Check the logs of the `cloud-pak-deployer` job
* If needed, make changes to the `cloud-pak-deployer-config` Config Map by going to Workloads --> ConfigMaps
* [Re-run the deployer](#start-the-deployer)