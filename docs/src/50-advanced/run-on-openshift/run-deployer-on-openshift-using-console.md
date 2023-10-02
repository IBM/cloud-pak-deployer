# Running deployer on OpenShift using console

## Log in to the OpenShift cluster
Log is as a cluster administrator to be able to run the deployer with the correct permissions.

## Make sure you have a default storage class
* Go to Storage --> StorageClasses
* Check if you have a default storage class (grey `Default` annotation)
* If you don't, click on a "file" storage class (`ocs-storagecluster-cephfs` if you have ODF, `managed-nfs-storage` if you have NFS)
* Click Actions --> Annotations at the top right
* Add an entry with key `storageclass.kubernetes.io/is-default-class` and value `true`
* Click save

Now you should have a default storage class that the deployer will use to store its statue information.

## Prepare the deployer project and the storage
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
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloud-pak-deployer-status
  namespace: cloud-pak-deployer
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

## Set the entitlement key
* Update the secret below with your Cloud Pak entitlement key. Make sure the key is indented exactly as below.
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the follliwng block, **adjust where needed**
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

## Configure the Cloud Paks and service to be deployed
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
      ocp_version: "4.10"
      cluster_name: cpd-demo
      domain_name: example.com
      openshift_storage:
      - storage_name: auto-storage
        storage_type: auto

    cp4d:
    - project: cpd
      openshift_cluster_name: cpd-demo
      cp4d_version: 4.7.3
      sequential_install: True
      accept_licenses: True
      cartridges:
      - name: cp-foundation
        license_service:
          state: disabled
          threads_per_core: 2
      - name: lite

      - name: analyticsengine 
        size: small 
        state: removed

      - name: bigsql
        state: removed

      - name: ca
        size: small
        instances:
        - name: ca-instance
          metastore_ref: ca-metastore
        state: removed

      - name: cde
        state: removed

      - name: datagate
        state: removed

      - name: datastage-ent-plus
        state: removed

      - name: db2
        size: small
        instances:
        - name: ca-metastore
          metadata_size_gb: 20
          data_size_gb: 20
          backup_size_gb: 20  
          transactionlog_size_gb: 20
        state: removed

      - name: db2wh
        state: removed

      - name: dmc
        state: removed

      - name: dods
        size: small
        state: removed

      - name: dp
        size: small
        state: removed

      - name: dv
        size: small 
        instances:
        - name: data-virtualization
        state: removed

      - name: factsheet
        size: small
        state: removed

      - name: hadoop
        size: small
        state: removed

      - name: mantaflow
        size: small
        state: removed

      - name: match360
        size: small
        wkc_enabled: true
        state: removed

      - name: openpages
        state: installed
        instances:
        - name: openpages-instance
          size: xsmall

      - name: planning-analytics
        state: removed

      - name: rstudio
        size: small
        state: removed

      - name: spss
        state: removed

      - name: voice-gateway
        replicas: 1
        state: removed

      - name: watson-assistant
        size: small
        state: removed

      - name: watson-discovery
        state: removed

      - name: watson-ks
        size: small
        state: removed

      - name: watson-openscale
        size: small
        state: removed

      - name: watson-speech
        stt_size: xsmall
        tts_size: xsmall
        state: removed

      - name: wkc
        size: small
        state: removed
        installation_options:
          install_wkc_core_only: True
          enableKnowledgeGraph: False
          enableDataQuality: False
          enableFactSheet: False

      - name: wml
        size: small
        state: installed

      - name: wml-accelerator
        replicas: 1
        size: small
        state: removed

      - name: ws
        state: installed

      - name: ws-pipelines
        state: removed
```

## Run the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
```
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: cloud-pak-deployer
  name: cloud-pak-deployer
  namespace: cloud-pak-deployer
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 2
  template:
    metadata:
      name: cloud-pak-deployer
      labels:
        app: cloud-pak-deployer
    spec:
      containers:
      - name: cloud-pak-deployer
        image: quay.io/cloud-pak-deployer/cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        env:
        - name: CONFIG_DIR
          value: /Data/cpd-config
        - name: STATUS_DIR
          value: /Data/cpd-status
        - name: CP_ENTITLEMENT_KEY
          valueFrom:
            secretKeyRef:
              key: cp-entitlement-key
              name: cloud-pak-entitlement-key
        volumeMounts:
        - name: config-volume
          mountPath: /Data/cpd-config/config
        - name: status-volume
          mountPath: /Data/cpd-status
        command: ["/bin/sh","-xc"]
        args: 
          - /cloud-pak-deployer/cp-deploy.sh env apply -v
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
      volumes:
      - name: config-volume
        configMap:
          name: cloud-pak-deployer-config
      - name: status-volume
        persistentVolumeClaim:
          claimName: cloud-pak-deployer-status        
```

## Optional: start debug job
The debug job can be useful if you want to access the status directory of the deployer if the deployer job has failed.

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
```
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: cloud-pak-deployer-debug
  name: cloud-pak-deployer-debug
  namespace: cloud-pak-deployer
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 0
  template:
    metadata:
      name: cloud-pak-deployer-debug
      labels:
        app: cloud-pak-deployer-debug
    spec:
      containers:
      - name: cloud-pak-deployer-debug
        image: quay.io/cloud-pak-deployer/cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        env:
        - name: CONFIG_DIR
          value: /Data/cpd-config
        - name: STATUS_DIR
          value: /Data/cpd-status
        volumeMounts:
        - name: config-volume
          mountPath: /Data/cpd-config/config
        - name: status-volume
          mountPath: /Data/cpd-status
        command: ["/bin/sh","-xc"]
        args: 
          - sleep infinity
      restartPolicy: Never
      securityContext:
        runAsUser: 0
      serviceAccountName: cloud-pak-deployer-sa
      volumes:
      - name: config-volume
        configMap:
          name: cloud-pak-deployer-config
      - name: status-volume
        persistentVolumeClaim:
          claimName: cloud-pak-deployer-status        
```

## Follow the logs of the deployment
* Open the OpenShift console
* Go to Compute --> Pods
* Select `cloud-pak-deployer` as the project at the top of the page
* Click the deployer pod
* Click logs

!!! info
    When running the deployer installing Cloud Pak for Data, the first run will fail. This is because the deployer applies the node configuration to OpenShift, which will cause all nodes to restart one by one, including the node that runs the deployer. Because of the job setting, a new deployer pod will automatically start and resume from where it was stopped.  

## Re-run deployer when failed or if you want to update the configuration
If the deployer has failed or if you want to make changes to the configuration after the successful run, you can do the following:

* Open the OpenShift console
* Go to Workloads --> Jobs
* Delete the `cloud-pak-deployer` job including dependent assets. This will delete the job and also running/completed pod
* Make changes to the `cloud-pak-deployer-config` Config Map by going to Workloads --> ConfigMaps
* [Re-run the deployer](#run-the-deployer)