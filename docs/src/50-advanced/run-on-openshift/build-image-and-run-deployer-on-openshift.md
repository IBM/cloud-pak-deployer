# Build image and run deployer on OpenShift

## Create configuration
``` { .bash .copy }
export CONFIG_DIR=$HOME/cpd-config && mkdir -p $CONFIG_DIR/config

cat << EOF > $CONFIG_DIR/config/cpd-config.yaml
---
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
  - storage_name: nfs-storage
    storage_type: nfs

cp4d:
- project: cpd-instance
  openshift_cluster_name: cpd-demo
  cp4d_version: 4.8.3
  accept_licenses: True
  cartridges:
  - name: cp-foundation
    license_service:
      state: disabled
      threads_per_core: 2
  - name: lite

#
# All tested cartridges. To install, change the "state" property to "installed". To uninstall, change the state
# to "removed" or comment out the entire cartridge. Make sure that the "-" and properties are aligned with the lite
# cartridge; the "-" is at position 3 and the property starts at position 5.
#

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

    # The default instance is created automatically with the DataStage installation. If you want to create additional instances
    # uncomment the section below and specify the various scaling options.

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

  - name: hadoop
    size: small
    state: removed

  - name: mdm
    size: small
    wkc_enabled: true
    state: removed

  - name: openpages
    state: removed

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

  - name: wml
    size: small
    state: installed

  - name: wml-accelerator
    replicas: 1
    size: small
    state: removed

  - name: wsl
    state: installed

EOF
```

## Log in to the OpenShift cluster
Log is as a cluster administrator to be able to run the deployer with the correct permissions.

## Prepare the deployer project
``` { .bash .copy }
oc new-project cloud-pak-deployer 

oc project cloud-pak-deployer
oc create serviceaccount cloud-pak-deployer-sa
oc adm policy add-scc-to-user privileged -z cloud-pak-deployer-sa
oc adm policy add-cluster-role-to-user cluster-admin -z cloud-pak-deployer-sa
```

## Build deployer image and push to the internal registry
Building the deployer image typically takes ~5 minutes. Only do this if the image has not been built yet.

``` { .bash .copy }
cat << EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: cloud-pak-deployer
spec:
  lookupPolicy:
    local: true
EOF

cat << EOF | oc create -f -
kind: Build
apiVersion: build.openshift.io/v1
metadata:
  generateName: cloud-pak-deployer-bc-
  namespace: cloud-pak-deployer
spec:
  serviceAccount: builder
  source:
    type: Git
    git:
      uri: 'https://github.com/IBM/cloud-pak-deployer'
      ref: wizard
  strategy:
    type: Docker
    dockerStrategy:
      buildArgs:
      - name: CPD_OLM_UTILS_V2_IMAGE
        value: icr.io/cpopen/cpd/olm-utils-v2:latest
      - name: CPD_OLM_UTILS_V3_IMAGE
        value: icr.io/cpopen/cpd/olm-utils-v3:latest
  output:
    to:
      kind: ImageStreamTag
      name: 'cloud-pak-deployer:latest'
  triggeredBy:
    - message: Manually triggered
EOF
```

Now, wait until the deployer image has been built.
``` { .bash .copy }
oc get build -n cloud-pak-deployer -w
```

## Set configuration
``` { .bash .copy }
oc create cm -n cloud-pak-deployer cloud-pak-deployer-config
oc set data -n cloud-pak-deployer cm/cloud-pak-deployer-config \
  --from-file=$CONFIG_DIR/config
```
  
## Start the deployer job
``` { .bash .copy }
export CP_ENTITLEMENT_KEY=your_entitlement_key

cat << EOF | oc apply -f -
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
EOF

cat << EOF | oc apply -f -
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
  backoffLimit: 0
  template:
    metadata:
      name: cloud-pak-deployer
      labels:
        app: cloud-pak-deployer
    spec:
      containers:
      - name: cloud-pak-deployer
        image: cloud-pak-deployer:latest
        imagePullPolicy: Always
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        env:
        - name: CONFIG_DIR
          value: /Data/cpd-config
        - name: STATUS_DIR
          value: /Data/cpd-status
        - name: CP_ENTITLEMENT_KEY
          value: ${CP_ENTITLEMENT_KEY}
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
EOF
```

## Optional: start debug job
The debug job can be useful if you want to access the status directory of the deployer if the deployer job has failed.
``` { .bash .copy }
cat << EOF | oc apply -f -
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
        image: cloud-pak-deployer:latest
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
EOF
```

## Follow the logs of the deployment
``` { .bash .copy }
oc logs -f -n cloud-pak-deployer job/cloud-pak-deployer
```

In some cases, especially if the OpenShift cluster is remote from where the `oc` command is running, the `oc logs -f` command may terminate abruptly. 
