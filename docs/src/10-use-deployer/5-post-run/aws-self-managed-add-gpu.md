# Adding GPU nodes to self-managed OpenShift on AWS

When deploying self-managed OpenShift on AWS, the compute nodes are represented as one or more OpenShift `MachineSet`s. If your cluster is deployed in a single zone, there will be 1 `MachineSet` which defines the number and type of ec2 instances created in the AWS account. For multi-zone clusters, there will be 3 `MachineSet`s.

## Find the compute node `MachineSet`
Below is an example of a compute node (worker) `MachineSet` created by the OpenShift installer. The instance type defines the node that is spun up, with 32 vCPUs and 128 GB of memory.
```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  annotations:
    capacity.cluster-autoscaler.kubernetes.io/labels: kubernetes.io/arch=amd64
    machine.openshift.io/GPU: '0'
    machine.openshift.io/memoryMb: '131072'
    machine.openshift.io/vCPU: '32'
  resourceVersion: '22985'
  name: fk-aws-sts-2th7t-worker-us-east-1a
  uid: be5a9880-eaa0-4054-a77f-e5c4432eb51f
  creationTimestamp: '2024-10-16T20:30:43Z'
  generation: 1
  managedFields:
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:metadata':
          'f:labels':
            .: {}
            'f:machine.openshift.io/cluster-api-cluster': {}
        'f:spec':
          .: {}
          'f:replicas': {}
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
                  'f:instanceType': {}
                  'f:metadata':
                    .: {}
                    'f:creationTimestamp': {}
                  'f:blockDevices': {}
                  'f:kind': {}
                  'f:securityGroups': {}
                  'f:deviceIndex': {}
                  'f:ami':
                    .: {}
                    'f:id': {}
                  'f:metadataServiceOptions': {}
                  'f:tags': {}
                  .: {}
                  'f:placement':
                    .: {}
                    'f:availabilityZone': {}
                    'f:region': {}
                  'f:subnet':
                    .: {}
                    'f:filters': {}
                  'f:apiVersion': {}
                  'f:iamInstanceProfile':
                    .: {}
                    'f:id': {}
                  'f:credentialsSecret':
                    .: {}
                    'f:name': {}
                  'f:userDataSecret':
                    .: {}
                    'f:name': {}
      manager: cluster-bootstrap
      operation: Update
      time: '2024-10-16T20:30:43Z'
    - apiVersion: machine.openshift.io/v1beta1
      fieldsType: FieldsV1
      fieldsV1:
        'f:status': {}
      manager: cluster-bootstrap
      operation: Update
      subresource: status
      time: '2024-10-16T20:30:43Z'
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
      time: '2024-10-16T20:35:26Z'
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
      time: '2024-10-16T20:41:50Z'
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
spec:
  replicas: 3
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
      machine.openshift.io/cluster-api-machineset: fk-aws-sts-2th7t-worker-us-east-1a
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: fk-aws-sts-2th7t-worker-us-east-1a
    spec:
      lifecycleHooks: {}
      metadata: {}
      providerSpec:
        value:
          userDataSecret:
            name: worker-user-data
          placement:
            availabilityZone: us-east-1a
            region: us-east-1
          credentialsSecret:
            name: aws-cloud-credentials
          instanceType: m5.8xlarge
          metadata:
            creationTimestamp: null
          blockDevices:
            - ebs:
                encrypted: true
                iops: 0
                kmsKey:
                  arn: ''
                volumeSize: 120
                volumeType: gp3
          securityGroups:
            - filters:
                - name: 'tag:Name'
                  values:
                    - fk-aws-sts-2th7t-worker-sg
          kind: AWSMachineProviderConfig
          metadataServiceOptions: {}
          tags:
            - name: kubernetes.io/cluster/fk-aws-sts-2th7t
              value: owned
          deviceIndex: 0
          ami:
            id: ami-0d653d86d4113326a
          subnet:
            filters:
              - name: 'tag:Name'
                values:
                  - fk-aws-sts-2th7t-private-us-east-1a
          apiVersion: machine.openshift.io/v1beta1
          iamInstanceProfile:
            id: fk-aws-sts-2th7t-worker-profile
status:
  availableReplicas: 3
  fullyLabeledReplicas: 3
  observedGeneration: 1
  readyReplicas: 3
  replicas: 3

```

## Transform to GPU `MachineSet`

To create a GPU `MachineSet` in the same region, copy the yaml into your favourite text editor and remove all the unnecessary properties. Below is an example of the resulting yaml, highlighting the items that have changed to define the GPU node(s). In this example there is only 1 GPU node of type `g6e.8xlarge`. Only the highlighted properties should be changed.

```yaml linenums="1" hl_lines="4 9 13 20 31"
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: fk-aws-sts-2th7t-gpu-us-east-1a
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
      machine.openshift.io/cluster-api-machineset: fk-aws-sts-2th7t-gpu-us-east-1a
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: fk-aws-sts-2th7t
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: fk-aws-sts-2th7t-gpu-us-east-1a
    spec:
      providerSpec:
        value:
          userDataSecret:
            name: worker-user-data
          placement:
            availabilityZone: us-east-1a
            region: us-east-1
          credentialsSecret:
            name: aws-cloud-credentials
          instanceType: g6e.8xlarge
          metadata:
            creationTimestamp: null
          blockDevices:
            - ebs:
                encrypted: true
                iops: 0
                kmsKey:
                  arn: ''
                volumeSize: 120
                volumeType: gp3
          securityGroups:
            - filters:
                - name: 'tag:Name'
                  values:
                    - fk-aws-sts-2th7t-worker-sg
          kind: AWSMachineProviderConfig
          metadataServiceOptions: {}
          tags:
            - name: kubernetes.io/cluster/fk-aws-sts-2th7t
              value: owned
          deviceIndex: 0
          ami:
            id: ami-0d653d86d4113326a
          subnet:
            filters:
              - name: 'tag:Name'
                values:
                  - fk-aws-sts-2th7t-private-us-east-1a
          apiVersion: machine.openshift.io/v1beta1
          iamInstanceProfile:
            id: fk-aws-sts-2th7t-worker-profile
```

## Create the GPU `MachineSet`
Once ready, do the following to create the `MachineSet`:

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the updated yaml into the the window

The `MachineSet` will create `Machine` CRs in the `openshift-machines` project. If the instance type is available in the selected AWS region and there is enough capacity, the AWS instance(s) will be created and after a 5-10 minutes, it/they will appear as nodes in the OpenShift cluster.