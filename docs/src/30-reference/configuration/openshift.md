# OpenShift cluster(s)

You can configure one or more OpenShift clusters that will be layed down on the specified infrastructure, or which already exist.

Dependent on the cloud platform on which the OpenShift cluster will be provisioned, different installation methods apply. For IBM Cloud, Terraform is used, whereas for vSphere the IPI installer is used. On AWS (ROSA), the `rosa` CLI is used to create and modify ROSA clusters. Each of the different platforms have slightly different properties for the `openshift` objects.

## `openshift`

For OpenShift, there are 5 flavours:

- [Existing OpenShift](#existing-openshift)
- [OpenShift on IBM Cloud](#openshift-on-ibm-cloud-roks)
- [OpenShift on AWS - ROSA](#openshift-on-aws---rosa)
- [OpenShift on AWS - self-managed](#openshift-on-aws---self-managed)
- [OpenShift on Microsoft Azure (ARO)](#openshift-on-microsoft-azure-aro)
- [OpenShift on vSphere](#openshift-on-vsphere)

Every OpenShift cluster definition of a few mandatory properties that control which version of OpenShift is installed, the number and flavour of control plane and compute nodes and the underlying infrastructure, dependent on the cloud platform on which it is provisioned. Storage is a mandatory element for every `openshift` definition. For a list of supported storage types per cloud platform, refer to [Supported storage types](#supported-storage-types).

Additionally, one can configure [Upstream DNS Servers](./dns.md) and [OpenShift logging](logging-auditing.md).

The Multicloud Object Gateway (MCG) supports access to s3-compatible object storage via an underpinning block/file storage class, through the Noobaa operator. Some Cloud Pak for Data services such as Watson Assistant need object storage to run. MCG does not need to be installed if OpenShift Data Foundation (fka OCS) is also installed as the operator includes Noobaa.

### OpenShift on IBM Cloud (ROKS)
VPC-based OpenShift cluster on IBM Cloud, using the Red Hat OpenShift Kubernetes Services (ROKS).
```
openshift:
- name: sample
  managed: True
  ocp_version: 4.8
  compute_flavour: bx2.16x64
  compute_nodes: 3
  cloud_native_toolkit: False
  oadp: False
  infrastructure:
    type: vpc
    vpc_name: sample
    subnets:
    - sample-subnet-zone-1
    - sample-subnet-zone-2
    - sample-subnet-zone-3
    cos_name: sample-cos
    private_only: False
    deny_node_ports: False
  upstream_dns:
  - name: sample-dns
     zones:
     - example.com
     dns_servers:
     - 172.31.2.73:53
  mcg:
    install: True
    storage_type: storage-class
    storage_class: managed-nfs-storage
  openshift_storage:
  - storage_name: nfs-storage
    storage_type: nfs
    nfs_server_name: sample-nfs
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 500
    ocs_version: 4.8.0
  - storage_name: pwx-storage
    storage_type: pwx 
    pwx_etcd_location: {{ ibm_cloud_region }}
    pwx_storage_size_gb: 200 
    pwx_storage_iops: 10 
    pwx_storage_profile: "10iops-tier"
    stork_version: 2.6.2
    portworx_version: 2.7.2
```

#### Property explanation OpenShift clusters on IBM Cloud (ROKS)

| Property                         | Description                                                                                                                                                                                      | Mandatory               | Allowed values                                                                   |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------|----------------------------------------------------------------------------------|
| name                             | Name of the OpenShift cluster                                                                                                                                                                    | Yes                     |                                                                                  |
| managed                          | Is the ROKS cluster managed by this deployer? See note below.                                                                                                                                    | No                      | True (default), False                                                            |
| ocp_version                      | ROKS Kubernetes version. If you want to install `4.10`, specify `"4.10"`                                                                                                                         | Yes                     | >= 4.6                                                                           |
| compute_flavour                  | Type of compute node to be used                                                                                                                                                                  | Yes                     | [Node flavours](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=api) |
| compute_nodes                    | Total number of compute nodes. This must be a factor of the number of subnets                                                                                                                    | Yes                     | Integer                                                                          |
| resource_group                   | IBM Cloud resource group for the ROKS cluster                                                                                                                                                    | Yes                     |                                                                                  |
| cloud_native_toolkit             | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                                                                                                                                   | No                      | True, False (default)                                                            |
| oadp                             | Must the OpenShift Advanced Data Protection operator be installed                                                                                                                                | No                      | True, False (default)                                                            |
| infrastructure.type              | Type of infrastructure to provision ROKS cluster on                                                                                                                                              | No                      | vpc                                                                              |
| infrastructure.vpc_name          | Name of the VPC if type is `vpc`                                                                                                                                                                 | Yes, inferrred from vpc | Existing VPC                                                                     |
| infrastructure.subnets           | List of subnets within the VPC to use. Either 1 or 3 subnets must be specified                                                                                                                   | Yes                     | Existing subnet                                                                  |
| infrastructure.cos_name          | Reference to the `cos` object created for this cluster                                                                                                                                           | Yes                     | Existing cos object                                                              |
| infrastructure.private_only      | If true, it indicates that the ROKS cluster must be provisioned without public endpoints                                                                                                         | No                      | True, False (default)                                                            |
| infrastructure.deny_node_ports   | If true, the Allow ICMP, TCP and UDP rules for the security group associated with the ROKS cluster are removed if present. If false, the Allow ICMP, TCP and UDP rules are added if not present. | No                      | True, False (default)                                                            |
| infrastructure.secondary_storage | Reference to the storage flavour to be used as secondary storage, for example `"900gb.5iops-tier"`                                                                                               | No                      | Valid secondary storage flavour                                                  |
| openshift_logging[]              | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)                                                                                                           | No                      |                                                                                  |
| upstream_dns[]                   | Upstream DNS servers(s), see [Upstream DNS Servers](./dns.md)                                                                                                                                    | No                      |                                                                                  |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]              | List of storage definitions to be defined on OpenShift, see below for further explanation                                                                                                        | Yes                     |                                                                                  |

The `managed` attribute indicates whether the ROKS cluster is managed by the Cloud Pak Deployer. If set to `False`, the deployer will not provision the ROKS cluster but expects it to already be available in the VPC. You can still use the deployer to create the VPC, the subnets, NFS servers and other infrastructure, but first run it without an `openshift` element. Once the VPC has been created, manually create an OpenShift cluster in the VPC and then add the `openshift` element with `managed` set to `False`. If you intend to use OpenShift Container Storage, you must also activate the add-on and create the `OcsCluster` custom resource.

!!! warning
    If you set `infrastructure.private_only` to `True`, the server from which you run the deployer must be able to access the ROKS cluster via its private endpoint, either by establishing a VPN to the cluster's VPC, or by making sure the deployer runs on a server that has a connection with the ROKS VPC via a transit gateway.

##### openshift_storage[] - OpenShift storage definitions

| Property            | Description                                                                                     | Mandatory                      | Allowed values        |
|---------------------|-------------------------------------------------------------------------------------------------|--------------------------------|-----------------------|
| openshift_storage[] | List of storage definitions to be defined on OpenShift                                          | Yes                            |                       |
| storage_name        | Name of the storage definition, to be referenced by the Cloud Pak                               | Yes                            |                       |
| storage_type        | Type of storage class to create in the OpenShift cluster                                        | Yes                            | nfs, ocs or pwx       |
| nfs_server_name     | Name of the NFS server within the VPC                                                           | Yes if `storage_type` is `nfs` | Existing `nfs_server` |
| ocs_storage_label   | Label to be used for the dedicated OCS nodes in the cluster                                     | Yes if `storage_type` is `ocs` |                       |
| ocs_storage_size_gb | Size of the OCS storage in Gibibytes (Gi)                                                       | Yes if `storage_type` is `ocs` |                       |
| ocs_version         | Version of OCS (ODF) to be deployed. If left empty, the latest version will be deployed         | No                             | >= 4.6                |
| pwx_etcd_location   | Location where the etcd service will be deployed, typically the same region as the ROKS cluster | Yes if `storage_type` is `pwx` |                       |
| pwx_storage_size_gb | Size of the Portworx storage that will be provisioned                                           | Yes if `storage_type` is `pwx` |                       |
| pwx_storage_iops    | IOPS for the storage volumes that will be provisioned                                           | Yes if `storage_type` is `pwx` |                       |
| pwx_storage_profile | IOPS storage tier the storage volumes that will be provisioned                                  | Yes if `storage_type` is `pwx` |                       |
| stork_version       | Version of the Portworx storage orchestration layer for Kubernetes                              | Yes if `storage_type` is `pwx` |                       |
| portworx_version    | Version of the Portworx storage provider                                                        | Yes if `storage_type` is `pwx` |                       |

!!! warning
    When deploying a ROKS cluster with OpenShift Data Foundation (fka OpenShift Container Storage/OCS), the minimum version of OpenShift is 4.7.

### OpenShift on vSphere

```
openshift:
- name: sample
  domain_name: example.com
  vsphere_name: sample
  ocp_version: 4.8
  control_plane_nodes: 3
  control_plane_vm_definition: control-plane
  compute_nodes: 3
  compute_vm_definition: compute
  api_vip: 10.99.92.51
  ingress_vip: 10.99.92.52
  cloud_native_toolkit: False
  oadp: False
  infrastructure:
    openshift_cluster_network_cidr: 10.128.0.0/14
  upstream_dns:
  - name: sample-dns
     zones:
     - example.com
     dns_servers:
     - 172.31.2.73:53
  mcg:
    install: True
    storage_type: storage-class
    storage_class: thin
  openshift_storage:
  - storage_name: nfs-storage
    storage_type: nfs
    nfs_server_name: sample-nfs
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 512
    ocs_dynamic_storage_class: thin

```

#### Property explanation OpenShift clusters on vSphere

| Property                                      | Description                                                                                                                                               | Mandatory | Allowed values           |
|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------|
| name                                          | Name of the OpenShift cluster                                                                                                                             | Yes       |                          |
| domain_name                                   | Domain name of the cluster, this will also depict the route to the API and ingress endpoints                                                              | Yes       |                          |
| ocp_version                                   | OpenShift version.  If you want to install `4.10`, specify `"4.10"`                                                                                       | Yes       | >= 4.6                   |
| control_plane_nodes                           | Total number of control plane nodes, typically 3                                                                                                          | Yes       | Integer                  |
| control_plane_vm_definition                   | `vm_definition` object that will be used to define number of vCPUs and memory for the control plane nodes                                                 | Yes       | Existing `vm_definition` |
| compute_nodes                                 | Total number of compute nodes                                                                                                                             | Yes       | Integer                  |
| compute_vm_definition                         | `vm_definition` object that will be used to define number of vCPUs and memory for the compute nodes                                                       | Yes       | Existing `vm_definition` |
| api_vip                                       | Virtual IP address that the installer will provision for the API server                                                                                   | Yes       |                          |
| ingress_vip                                   | Virtual IP address that the installer will provision for the ingress server                                                                               | Yes       |                          |
| cloud_native_toolkit                          | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                                                                                            | No        | True, False (default)    |
| oadp                                          | Must the OpenShift Advanced Data Protection operator be installed                                                                                         | No        | True, False (default)    |
| infrastructure                                | Infrastructure properties                                                                                                                                 | No        |                          |
| infrastructure.openshift_cluster_network_cidr | Network CIDR used by the OpenShift pods. Normally you would not have to change this, unless other systems in the network are in the 10.128.0.0/14 subnet. | No        | CIDR                     |
| openshift_logging[]                           | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)                                                                    | No        |                          |
| upstream_dns[]                                | Upstream DNS servers(s), see [Upstream DNS Servers](./dns.md)                                                                                             | No        |                          |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]                           | List of storage definitions to be defined on OpenShift, see below for further explanation                                                                 | Yes       |                          |


##### openshift_storage[] - OpenShift storage definitions

| Property                  | Description                                                                                                                         | Mandatory                      | Allowed values        |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|-----------------------|
| openshift_storage[]       | List of storage definitions to be defined on OpenShift                                                                              | Yes                            |                       |
| storage_name              | Name of the storage definition, to be referenced by the Cloud Pak                                                                   | Yes                            |                       |
| storage_type              | Type of storage class to create in the OpenShift cluster                                                                            | Yes                            | nfs or ocs            |
| nfs_server_name           | Name of the NFS server within the VPC                                                                                               | Yes if `storage_type` is `nfs` | Existing `nfs_server` |
| ocs_version               | Version of the OCS operator. If not specified, this will default to the `ocp_version`                                               | No                             | >= 4.6                |
| ocs_storage_label         | Label to be used for the dedicated OCS nodes in the cluster                                                                         | Yes if `storage_type` is `ocs` |                       |
| ocs_storage_size_gb       | Size of the OCS storage in Gibibytes (Gi)                                                                                           | Yes if `storage_type` is `ocs` |                       |
| ocs_dynamic_storage_class | Storage class that will be used for provisioning OCS. On vSphere clusters, `thin` is usually available after OpenShift installation | Yes if `storage_type` is `ocs` |                       |
| storage_vm_definition     | VM Definition that defines the virtual machine attributes for the OCS nodes                                                         | Yes if `storage_type` is `ocs` |                       |

### OpenShift on AWS - self-managed

```
nfs_server:
- name: sample-elastic
  infrastructure:
    aws_region: eu-west-1

openshift:
- name: sample
  ocp_version: 4.10.34
  domain_name: cp-deployer.eu
  compute_flavour: m5.4xlarge
  compute_nodes: 3
  cloud_native_toolkit: False
  oadp: False
  infrastructure:
    type: self-managed
    aws_region: eu-central-1
    multi_zone: True
    credentials_mode: Manual
    private_only: True
    machine_cidr: 10.2.1.0/24
    openshift_cluster_network_cidr: 10.128.0.0/14
    subnet_ids:
    - subnet-06bbef28f585a0dd3
    - subnet-0ea5ac344c0fbadf5
    hosted_zone_id: Z08291873MCIC4TMIK4UP
    ami_id: ami-09249dd86b1933dd5
  mcg:
    install: True
    storage_type: storage-class
    storage_class: gp3-csi
  openshift_storage:
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 512
  - storage_name: sample-elastic
    storage_type: aws-elastic
```

#### Property explanation OpenShift clusters on AWS (self-managed)

| Property                                      | Description                                                                                                                                                                                                                                                 | Mandatory | Allowed values           |
|-----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------|
| name                                          | Name of the OpenShift cluster                                                                                                                                                                                                                               | Yes       |                          |
| ocp_version                                   | OpenShift version version, specified as `x.y.z`                                                                                                                                                                                                             | Yes       | >= 4.6                   |
| domain_name                                   | Base domain name of the cluster. Together with the `name`, this will be the domain of the OpenShift cluster.                                                                                                                                                | Yes       |                          |
| control_plane_flavour                         | Flavour of the AWS servers used for the control plane nodes. `m5.xxlarge` is the recommended value     4 GB of memory                                                                                                                                       | Yes       |                          |
| control_plane_nodes                           | Total number of control plane                                                                                                                                                                                                                               | Yes       | Integer                  |
| compute_flavour                               | Flavour of the AWS servers used for the compute nodes. `m5.4xlarge` is a large node with 16 cores and 64 GB of memory                                                                                                                                       | Yes       |                          |
| compute_nodes                                 | Total number of compute nodes                                                                                                                                                                                                                               | Yes       | Integer                  |
| cloud_native_toolkit                          | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                                                                                                                                                                                              | No        | True, False (default)    |
| oadp                                          | Must the OpenShift Advanced Data Protection operator be installed                                                                                                                                                                                           | No        | True, False (default)    |
| infrastructure                                | Infrastructure properties                                                                                                                                                                                                                                   | Yes       |                          |
| infrastructure.type                           | Type of OpenShift cluster on AWS.                                                                                                                                                                                                                           | Yes       | `rosa` or `self-managed` |
| infrastructure.aws_region                     | Region of AWS where cluster is deployed.                                                                                                                                                                                                                    | Yes       |                          |
| infrastructure.multi_zone                     | Determines whether the OpenShift cluster is deployed across multiple availability zones. Default is True.                                                                                                                                                   | No        | True (default), False    |
| infrastructure.credentials_mode               | Security requirement of the Cloud Credential Operator (COO) when doing installations with temporary AWS security credentials. Default (omit) is automatically handled by CCO.                                                                               | No        | Manual, Mint             |
| infrastructure.machine_cdr                    | Machine CIDR. This value will be used to create the VPC and its subnets. In case of an existing VPC, specify the CIDR of that VPC.                                                                                                                          | No        | CIDR                     |
| infrastructure.openshift_cluster_network_cidr | Network CIDR used by the OpenShift pods. Normally you would not have to change this, unless other systems in the network are in the 10.128.0.0/14 subnet.                                                                                                   | No        | CIDR                     |
| infrastructure.subnet_ids                     | Existing public and private subnet IDs in the VPC to be used for the OpenShift cluster.  Must be specified in combination with machine_cidr and hosted_zone_id.                                                                                             | No        | Existing subnet IDs      |
| infrastructure.private_only                   | Indicates whether the OpenShift can be accessed from the internet. Default is True                                                                                                                                                                          | No        | True, False              |
| infrastructure.hosted_zone_id                 | ID of the AWS Route 53 hosted zone that controls the DNS entries. If not specified, the OpenShift installer will create a hosted zone for the specified `domain_name`. This attribute is only needed if you create the OpenShift cluster in an existing VPC | No        |                          |
| infrastructure.control_plane_iam_role         | If not standard, specify the IAM role that the OpenShift installer must use for the control plane nodes during cluster creation                                                                                                                             | No        |                          |
| infrastructure.compute_iam_role               | If not standard, specify the IAM role that the OpenShift installer must use for the compute nodes during cluster creation                                                                                                                                   | No        |                          |
| infrastructure.ami_id                         | ID of the AWS AMI to boot all images                                                                                                                                                                                                                        | No        |                          |
| openshift_logging[]                           | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)                                                                                                                                                                      | No        |                          |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]                           | List of storage definitions to be defined on OpenShift, see below for further explanation                                                                                                                                                                   | Yes       |                          |

When deploying the OpenShift cluster within an existing VPC, you must specify the `machine_cidr` that covers all subnets and the subnet IDs within the VPC. For example:
```
    machine_cidr: 10.243.0.0/24
    subnets_ids:
    - subnet-0e63f662bb1842e8a
    - subnet-0673351cd49877269
    - subnet-00b007a7c2677cdbc
    - subnet-02b676f92c83f4422
    - subnet-0f1b03a02973508ed
    - subnet-027ca7cc695ce8515
```


##### openshift_storage[] - OpenShift storage definitions

| Property                  | Description                                                                                                       | Mandatory                      | Allowed values   |
|---------------------------|-------------------------------------------------------------------------------------------------------------------|--------------------------------|------------------|
| openshift_storage[]       | List of storage definitions to be defined on OpenShift                                                            | Yes                            |                  |
| storage_name              | Name of the storage definition, to be referenced by the Cloud Pak                                                 | Yes                            |                  |
| storage_type              | Type of storage class to create in the OpenShift cluster                                                          | Yes                            | ocs, aws-elastic |
| ocs_version               | Version of the OCS operator. If not specified, this will default to the `ocp_version`                             | No                             |                  |
| ocs_storage_label         | Label to be used for the dedicated OCS nodes in the cluster                                                       | Yes if `storage_type` is `ocs` |                  |
| ocs_storage_size_gb       | Size of the OCS storage in Gibibytes (Gi)                                                                         | Yes if `storage_type` is `ocs` |                  |
| ocs_dynamic_storage_class | Storage class that will be used for provisioning ODF. `gp3-csi` is usually available after OpenShift installation | No                             |                  |


### OpenShift on AWS - ROSA

```
nfs_server:
- name: sample-elastic
  infrastructure:
    aws_region: eu-west-1

openshift:
- name: sample
  ocp_version: 4.10.34
  compute_flavour: m5.4xlarge
  compute_nodes: 3
  cloud_native_toolkit: False
  oadp: False
  infrastructure:
    type: rosa
    aws_region: eu-central-1
    multi_zone: True
    use_sts: False
    credentials_mode: Manual
  upstream_dns:
  - name: sample-dns
     zones:
     - example.com
     dns_servers:
     - 172.31.2.73:53
  mcg:
    install: True
    storage_type: storage-class
    storage_class: gp3-csi
  openshift_storage:
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 512
  - storage_name: sample-elastic
    storage_type: aws-elastic
```

#### Property explanation OpenShift clusters on AWS (ROSA)

| Property                        | Description                                                                                                                                  | Mandatory | Allowed values           |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------|
| name                            | Name of the OpenShift cluster                                                                                                                | Yes       |                          |
| ocp_version                     | OpenShift version version, specified as `x.y.z`                                                                                              | Yes       | >= 4.6                   |
| compute_flavour                 | Flavour of the AWS servers used for the compute nodes. `m5.4xlarge` is a large node with 16 cores and 64 GB of memory                        | Yes       |                          |
| cloud_native_toolkit            | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                                                                               | No        | True, False (default)    |
| oadp                            | Must the OpenShift Advanced Data Protection operator be installed                                                                            | No        | True, False (default)    |
| infrastructure                  | Infrastructure properties                                                                                                                    | Yes       |                          |
| infrastructure.type             | Type of OpenShift cluster on AWS.                                                                                                            | Yes       | `rosa` or `self-managed` |
| infrastructure.aws_region       | Region of AWS where cluster is deployed.                                                                                                     | Yes       |                          |
| infrastructure.multi_zone       | Determines whether the OpenShift cluster is deployed across multiple availability zones. Default is True.                                    | No        | True (default), False    |
| infrastructure.use_sts          | Determines whether AWS Security Token Service must be used by the ROSA installer. Default is False.                                          | No        | True, False (default)    |
| infrastructure.credentials_mode | Change the security requirement of the Cloud Credential Operator (COO). Default (omit) is automatically handled by CCO.                      | No        | Manual, Mint             |
| infrastructure.machine_cdr      | Machine CIDR, for example 10.243.0.0/16.                                                                                                     | No        | CIDR                     |
| infrastructure.subnet_ids       | Existing public and private subnet IDs in the VPC to be used for the OpenShift cluster.  Must be specified in combination with machine_cidr. | No        | Existing subnet IDs      |
| compute_nodes                   | Total number of compute nodes                                                                                                                | Yes       | Integer                  |
| upstream_dns[]                  | Upstream DNS servers(s), see [Upstream DNS Servers](./dns.md)                                                                                | No        |                          |
| openshift_logging[]             | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)                                                       | No        |                          |
| upstream_dns[]                  | Upstream DNS servers(s), see [Upstream DNS Servers](#upstream-dns-servers)                                                                   | No        |                          |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]             | List of storage definitions to be defined on OpenShift, see below for further explanation                                                    | Yes       |                          |

When deploying the OpenShift cluster within an existing VPC, you must specify the `machine_cidr` that covers all subnets and the subnet IDs within the VPC. For example:
```
    machine_cidr: 10.243.0.0/24
    subnets_ids:
    - subnet-0e63f662bb1842e8a
    - subnet-0673351cd49877269
    - subnet-00b007a7c2677cdbc
    - subnet-02b676f92c83f4422
    - subnet-0f1b03a02973508ed
    - subnet-027ca7cc695ce8515
```

##### openshift_storage[] - OpenShift storage definitions

| Property                  | Description                                                                                                       | Mandatory                      | Allowed values   |
|---------------------------|-------------------------------------------------------------------------------------------------------------------|--------------------------------|------------------|
| openshift_storage[]       | List of storage definitions to be defined on OpenShift                                                            | Yes                            |                  |
| storage_name              | Name of the storage definition, to be referenced by the Cloud Pak                                                 | Yes                            |                  |
| storage_type              | Type of storage class to create in the OpenShift cluster                                                          | Yes                            | ocs, aws-elastic |
| ocs_version               | Version of the OCS operator. If not specified, this will default to the `ocp_version`                             | No                             |                  |
| ocs_storage_label         | Label to be used for the dedicated OCS nodes in the cluster                                                       | Yes if `storage_type` is `ocs` |                  |
| ocs_storage_size_gb       | Size of the OCS storage in Gibibytes (Gi)                                                                         | Yes if `storage_type` is `ocs` |                  |
| ocs_dynamic_storage_class | Storage class that will be used for provisioning ODF. `gp3-csi` is usually available after OpenShift installation | No                             |                  |


### OpenShift on Microsoft Azure (ARO)

```
openshift:
- name: sample
  azure_name: sample
  domain_name: example.com
  ocp_version: 4.10.54
  cloud_native_toolkit: False
  oadp: False
  network:
    pod_cidr: "10.128.0.0/14"
    service_cidr: "172.30.0.0/16"
  openshift_storage:
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 512
    ocs_dynamic_storage_class: managed-premium
```

#### Property explanation for OpenShift cluster on Microsoft Azure (ARO)

!!! warning
    You are not allowed to specify the OCP version of the ARO cluster. The latest current version is provisioned automatically instead no matter what value is specified in the "ocp_version" parameter. The "ocp_version" parameter is mandatory for compatibility with other layers of the provisioning, such as the OpenShift client. For instance, the value is used by the process which downloads and installs the `oc` client. Please, specify the value according to what OCP version will be provisioned.

| Property             | Description                                                                               | Mandatory | Allowed values                      |
|----------------------|-------------------------------------------------------------------------------------------|-----------|-------------------------------------|
| name                 | Name of the OpenShift cluster                                                             | Yes       |                                     |
| azure_name           | Name of the `azure` element in the configuration                                          | Yes       |                                     |
| domain_name          | Domain mame of the cluster, if you want to override the name generated by Azure           | No        |                                     |
| ocp_version          | The OpenShift version. If you want to install `4.10`, specify `"4.10"`                    | Yes       | >= 4.6                              |
| cloud_native_toolkit | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                            | No        | True, False (default)               |
| oadp                 | Must the OpenShift Advanced Data Protection operator be installed                         | No        | True, False (default)               |
| network              | Cluster network attributes                                                                | Yes       |                                     |
| network.pod_cidr     | CIDR of pod network                                                                       | Yes       | Must be a minimum of /18 or larger. |
| network.service_cidr | CIDR of service network                                                                   | Yes       | Must be a minimum of /18 or larger. |
| openshift_logging[]  | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)    | No        |                                     |
| upstream_dns[]       | Upstream DNS servers(s), see [Upstream DNS Servers](./dns.md)                             | No        |                                     |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]  | List of storage definitions to be defined on OpenShift, see below for further explanation | Yes       |                                     |

##### openshift_storage[] - OpenShift storage definitions

| Property                  | Description                                                                                                                                  | Mandatory                      | Allowed values    |
|---------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|-------------------|
| openshift_storage[]       | List of storage definitions to be defined on OpenShift                                                                                       | Yes                            |                   |
| storage_name              | Name of the storage                                                                                                                          | Yes                            |                   |
| storage_type              | Type of storage class to create in the OpenShift cluster                                                                                     | Yes                            | `ocs` or `nfs`    |
| ocs_version               | Version of the OCS operator. If not specified, this will default to the `ocp_version`                                                        | No                             |                   |
| ocs_storage_label         | Label (or rather a name) to be used for the dedicated OCS nodes in the cluster - together with the combination of Azure location and zone id | Yes if `storage_type` is `ocs` |                   |
| ocs_storage_size_gb       | Size of the OCS storage in Gibibytes (Gi)                                                                                                    | Yes if `storage_type` is `ocs` |                   |
| ocs_dynamic_storage_class | Storage class that will be used for provisioning OCS. In Azure, you must select `managed-premium`                                            | Yes if `storage_type` is `ocs` | `managed-premium` |

### Existing OpenShift

When using the Cloud Pak Deployer on an existing OpenShift cluster, the scripts assume that the cluster is already operational and that any storage classes have been pre-created. The deployer accesses the cluster through a vault secret with the kubeconfig information; the name of the secret is `<name>-kubeconfig`.

```
openshift:
- name: sample
  ocp_version: 4.8
  cluster_name: sample
  domain_name: example.com
  cloud_native_toolkit: False
  oadp: False
  infrastructure:
    type: standard
    processor_architecture: amd64
  upstream_dns:
  - name: sample-dns
     zones:
     - example.com
     dns_servers:
     - 172.31.2.73:53
  mcg:
    install: True
    storage_type: storage-class
    storage_class: managed-nfs-storage
  openshift_storage:
  - storage_name: nfs-storage
    storage_type: nfs
    # ocp_storage_class_file: managed-nfs-storage
    # ocp_storage_class_block: managed-nfs-storage
```

#### Property explanation for existing OpenShift clusters

| Property             | Description                                                                                                     | Mandatory | Allowed values        |
|----------------------|-----------------------------------------------------------------------------------------------------------------|-----------|-----------------------|
| name                 | Name of the OpenShift cluster                                                                                   | Yes       |                       |
| ocp_version          | OpenShift version of the cluster, used to download the client.  If you want to install `4.10`, specify `"4.10"` | Yes       | >= 4.6                |
| cluster_name         | Name of the cluster (part of the FQDN)                                                                          | Yes       |                       |
| domain_name          | Domain name of the cluster (part of the FQDN)                                                                   | Yes       |                       |
| cloud_native_toolkit | Must the Cloud Native Toolkit (OpenShift GitOps) be installed?                                                  | No        | True, False (default) |
| oadp                 | Must the OpenShift Advanced Data Protection operator be installed                                               | No        | True, False (default) |
| infrastructure.type                   | Infrastructure OpenShfit is deployed on. See below for additional explanation                                   | detect (default) |
| infrastructure.processor_architecture | Architecture of the processor that the OpenShift cluster is deployed on                                         | No               | amd64 (default), ppc64le, s390x |
| openshift_logging[]                   | Logging attributes for OpenShift cluster, see [OpenShift logging](logging-auditing.md)                          | No               |                                 |
| upstream_dns[]                        | Upstream DNS servers(s), see [Upstream DNS Servers](./dns.md)                                                   | No               |                                 |
| mcg                                           | Multicloud Object Gateway properties                                                                                                                      | No        |                          |
| mcg.install                                   | Must Multicloud Object Gateway be installed (Once installed, False does not uninstall)                                                                    | Yes       | True, False              |
| mcg.storage_type                              | Type of storage supporting the object Noobaa object storage                                                                                               | Yes       | storage-class            |
| mcg.storage_class                             | Storage class supporting the Noobaa object storage                                                                                                        | Yes       | Existing storage class   |
| openshift_storage[]                   | List of storage definitions to be defined on OpenShift, see below for further explanation                       | Yes              |                                 |

##### infastructure.type - Type of infrastructure
When deploying on existing OpenShift, the underlying infrastructure can pose some restrictions on capabilities available. For example, Red Hat OpenShift on IBM Cloud (aka ROKS) does not include the Machine Config Operator and ROSA on AWS does not allow to set labels for Machine Config Pools. This means that node settings required for Cloud Pak for Data must be applied in a non-standard manner.

The following values are allowed for `infrastructure.type`:

* `detect` (default): The deployer will attempt to detect the underlying cloud infrastructure. This is done by retrieving the existing storage classes and then inferring the cloud type.
* `standard`: The deployer will assume a standard OpenShift cluster with no further restrictions. This is the fallback value for `detect` if the underlying infra cannot be detected. 
* `aws-self-managed`: A self-managed OpenShift cluster on AWS. No restrictions.
* `aws-rosa`: Managed Red Hat OpenShift on AWS. Some restrictions with regards to Machine Config Pools apply.
* `azure-aro`: Managed Red Hat OpenShift on Azure. No known restrictions.
* `vsphere`: OpenShift on vSphere. No known restrictions.

##### openshift_storage[] - OpenShift storage definitions

| Property                | Description                                                                                 | Mandatory                         | Allowed values                      |
|-------------------------|---------------------------------------------------------------------------------------------|-----------------------------------|-------------------------------------|
| storage_name            | Name of the storage definition, to be referenced by the Cloud Pak                           | Yes                               |                                     |
| storage_type            | Type of storage class to use in the OpenShift cluster                                       | Yes                               | nfs, ocs, aws-elastic, auto, custom |
| ocp_storage_class_file  | OpenShift storage class to use for file storage if different from default for storage_type  | Yes if `storage_type` is `custom` |                                     |
| ocp_storage_class_block | OpenShift storage class to use for block storage if different from default for storage_type | Yes if `storage_type` is `custom` |                                     |

!!! info
    The custom storage_type can be used in case you want to use a non-standard storage class(es). In this case the storage class(es) must be already configured on the OCP cluster and set in the respective ocp_storage_class_file and ocp_storage_class_block variables

!!! info
    The auto storage_type will let the deployer automatically detect the storage type based on the existing storage classes in the OpenShift cluster.

## Supported storage types
An `openshift` definition always includes the type(s) of storage that it will provide. When the OpenShift cluster is provisioned by the deployer, the necessary infrastructure and storage class(es) are also configured. In case an existing OpenShift cluster is referenced by the configuration, the storage classes are expected to exist already.

The table below indicates which storage classes are supported by the Cloud Pak Deployer per cloud infrastructure.

!!! warning
    The ability to provision or use certain storage types does not imply support by the Cloud Paks or by OpenShift itself. There are several restrictions for production use OpenShift Data Foundation, for example when on ROSA.

| Cloud Provider | NFS Storage | OCS/ODF Storage | Portworx | Elastic | Custom (2) |
|----------------|-------------|-----------------|----------|---------|------------|
| ibm-cloud      | Yes         | Yes             | Yes      | No      | Yes        |
| vsphere        | Yes (1)     | Yes             | No       | No      | Yes        |
| aws            | No          | Yes             | No       | Yes (3) | Yes        |
| azure          | No          | Yes             | No       | No      | Yes        |
| existing-ocp   | Yes         | Yes             | No       | Yes     | Yes        |

* (1) An existing NFS server can be specified so that the deployer configures the `managed-nfs-storage` storage class. The deployer will not provision or change the NFS server itself.
* (2) If you specify a `custom` storage type, you must specify the storage class to be used for block (RWO) and file (RWX) storage.
* (3) Specifying this storage type means that Elastic File Storage (EFS) and Elastic Block Storage (EBS) storage classes will be used. For EFS, an `nfs_server` object is required to define the "file server" storage on AWS.