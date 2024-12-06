# Adding GPU nodes to self-managed OpenShift on Azure

When deploying self-managed OpenShift on Azure, the compute nodes are represented as one or more OpenShift `MachineSet`s. If your cluster is deployed in a single zone, there will be 1 `MachineSet` which defines the number and type of virtual machiness created in the Azure resource group. For multi-zone clusters, there will be 3 `MachineSet`s.

## Find the compute node `MachineSet`
Below is an example of a compute node (worker) `MachineSet` created by the OpenShift installer. The instance type defines the node that is spun up, with 32 vCPUs and 128 GB of memory.
``` { .yaml .copy }
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  annotations:
    capacity.cluster-autoscaler.kubernetes.io/labels: kubernetes.io/arch=amd64
    machine.openshift.io/GPU: '0'
    machine.openshift.io/memoryMb: '131072'
    machine.openshift.io/vCPU: '32'
  resourceVersion: '67642'
  name: fk-openshift-shtmp-worker-germanywestcentral1
  uid: 0104469b-71d9-413e-ad52-40a1a2168a84
  creationTimestamp: '2024-12-06T14:24:56Z'
  generation: 3
  managedFields:
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:spec':
          'f:replicas': {}
      manager: Mozilla
      operation: Update
      subresource: scale
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:metadata':
          'f:labels':
            .: {}
            'f:machine.openshift.io/cluster-api-cluster': {}
            'f:machine.openshift.io/cluster-api-machine-role': {}
            'f:machine.openshift.io/cluster-api-machine-type': {}
        'f:spec':
          .: {}
          'f:selector': {}
          'f:template':
            .: {}
            'f:metadata':
              .: {}
              'f:labels':
                .: {}
                'f:machine.openshift.io/cluster-api-cluster': {}
                'f:machine.openshift.io/cluster-api-machine-role': {}
                'f:machine.openshift.io/cluster-api-machine-type': {}
                'f:machine.openshift.io/cluster-api-machineset': {}
            'f:spec':
              .: {}
              'f:lifecycleHooks': {}
              'f:metadata': {}
              'f:providerSpec':
                .: {}
                'f:value':
                  'f:zone': {}
                  'f:metadata':
                    .: {}
                    'f:creationTimestamp': {}
                  'f:publicIP': {}
                  'f:image':
                    .: {}
                    'f:offer': {}
                    'f:publisher': {}
                    'f:resourceID': {}
                    'f:sku': {}
                    'f:version': {}
                  'f:acceleratedNetworking': {}
                  'f:kind': {}
                  'f:location': {}
                  'f:managedIdentity': {}
                  'f:vmSize': {}
                  .: {}
                  'f:subnet': {}
                  'f:apiVersion': {}
                  'f:securityProfile':
                    .: {}
                    'f:settings': {}
                  'f:osDisk':
                    .: {}
                    'f:diskSettings': {}
                    'f:diskSizeGB': {}
                    'f:managedDisk':
                      .: {}
                      'f:securityProfile':
                        .: {}
                        'f:diskEncryptionSet': {}
                      'f:storageAccountType': {}
                    'f:osType': {}
                  'f:networkResourceGroup': {}
                  'f:diagnostics': {}
                  'f:credentialsSecret':
                    .: {}
                    'f:name': {}
                    'f:namespace': {}
                  'f:publicLoadBalancer': {}
                  'f:userDataSecret':
                    .: {}
                    'f:name': {}
                  'f:vnet': {}
                  'f:resourceGroup': {}
      manager: cluster-bootstrap
      operation: Update
      time: '2024-12-06T14:24:56Z'
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:status': {}
      manager: cluster-bootstrap
      operation: Update
      subresource: status
      time: '2024-12-06T14:24:57Z'
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:metadata':
          'f:annotations':
            .: {}
            'f:capacity.cluster-autoscaler.kubernetes.io/labels': {}
            'f:machine.openshift.io/GPU': {}
            'f:machine.openshift.io/memoryMb': {}
            'f:machine.openshift.io/vCPU': {}
      manager: machine-controller-manager
      operation: Update
      time: '2024-12-06T14:37:14Z'
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:status':
          'f:availableReplicas': {}
          'f:fullyLabeledReplicas': {}
          'f:observedGeneration': {}
          'f:readyReplicas': {}
          'f:replicas': {}
      manager: machineset-controller
      operation: Update
      subresource: status
      time: '2024-12-06T15:54:53Z'
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
spec:
  replicas: 3
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
      machine.openshift.io/cluster-api-machineset: fk-openshift-shtmp-worker-germanywestcentral1
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: fk-openshift-shtmp-worker-germanywestcentral1
    spec:
      lifecycleHooks: {}
      metadata: {}
      providerSpec:
        value:
          osDisk:
            diskSettings: {}
            diskSizeGB: 300
            managedDisk:
              securityProfile:
                diskEncryptionSet: {}
              storageAccountType: Premium_LRS
            osType: Linux
          networkResourceGroup: fk-rg
          publicLoadBalancer: fk-openshift-shtmp
          userDataSecret:
            name: worker-user-data
          vnet: fk-openshift
          securityProfile:
            settings: {}
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          diagnostics: {}
          zone: '1'
          metadata:
            creationTimestamp: null
          publicIP: false
          resourceGroup: fk-openshift-rg
          kind: AzureMachineProviderSpec
          location: germanywestcentral
          vmSize: Standard_D32s_v3
          image:
            offer: ''
            publisher: ''
            resourceID: /resourceGroups/fk-openshift-rg/providers/Microsoft.Compute/galleries/gallery_fk_openshift_shtmp/images/fk-openshift-shtmp-gen2/versions/latest
            sku: ''
            version: ''
          acceleratedNetworking: true
          managedIdentity: fk-openshift-shtmp-identity
          subnet: control-plane
          apiVersion: machine.openshift.io/v1beta1
status:
  availableReplicas: 3
  fullyLabeledReplicas: 3
  observedGeneration: 3
  readyReplicas: 3
  replicas: 3
```

## Transform to GPU `MachineSet`

To create a GPU `MachineSet` in the same region, copy the yaml into your favourite text editor and remove all the unnecessary properties. Below is an example of the resulting yaml, highlighting the items that have changed to define the GPU node(s). In this example there is only 1 GPU node of type `Standard_NC96ads_A100_v4`. Only the highlighted properties should be changed.

``` { .yaml .copy linenums="1" hl_lines="4 9 13 20 47" }
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: fk-openshift-shtmp-gpu-germanywestcentral1
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
      machine.openshift.io/cluster-api-machineset: fk-openshift-shtmp-gpu-germanywestcentral1
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: fk-openshift-shtmp
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: fk-openshift-shtmp-gpu-germanywestcentral1
    spec:
      providerSpec:
        value:
          osDisk:
            diskSettings: {}
            diskSizeGB: 300
            managedDisk:
              securityProfile:
                diskEncryptionSet: {}
              storageAccountType: Premium_LRS
            osType: Linux
          networkResourceGroup: fk-rg
          publicLoadBalancer: fk-openshift-shtmp
          userDataSecret:
            name: worker-user-data
          vnet: fk-openshift
          securityProfile:
            settings: {}
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          zone: '1'
          publicIP: false
          resourceGroup: fk-openshift-rg
          kind: AzureMachineProviderSpec
          location: germanywestcentral
          vmSize: Standard_NC96ads_A100_v4
          image:
            offer: ''
            publisher: ''
            resourceID: /resourceGroups/fk-openshift-rg/providers/Microsoft.Compute/galleries/gallery_fk_openshift_shtmp/images/fk-openshift-shtmp-gen2/versions/latest
            sku: ''
            version: ''
          acceleratedNetworking: true
          managedIdentity: fk-openshift-shtmp-identity
          subnet: control-plane
          apiVersion: machine.openshift.io/v1beta1
```

## Create the GPU `MachineSet`
Once ready, do the following to create the `MachineSet`:

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the updated yaml into the the window

The `MachineSet` will create `Machine` CRs in the `openshift-machines` project. If the instance type is available in the selected Azure region and there is enough capacity, the Azure VM(s) will be created and after a 5-10 minutes, it/they will appear as nodes in the OpenShift cluster.