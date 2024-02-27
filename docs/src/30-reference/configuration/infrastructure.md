# Infrastructure

For some of the cloud platforms, you must explicitly specify the infrastructure layer on which the OpenShift cluster(s) will be provisioned, or you can override the defaults. 

For IBM Cloud, you can configure the VPC, subnets, NFS server(s), other Virtual Server Instance(s) and a number of other objects. When provisioning OpenShift on vSphere, you can configure data center, data store, network and virtual machine definitions. For Azure ARO you configure a single object with information about the virtual network (vnet) to be used and the node server profiles. When deploying OpenShift on AWS you can specify an EFS server if you want to use elastic storage.

This page lists all the objects you can configure for each of the supported cloud providers.
- [IBM Cloud](#ibm-cloud)
- [Microsoft Azure](#microsoft-azure)
- [Amazon AWS](#amazon)
- [vSphere](#vsphere)

## IBM Cloud

For IBM Cloud, the following object types are supported:

- [provider](#ibm-cloud-provider)
- [resource_group](#ibm-cloud-resource_group)
- [ssh_keys](#ibm-cloud-ssh_keys)
- [address_prefix](#ibm-cloud-address_prefix)
- [subnet](#ibm-cloud-subnet)
- [network_acl](#ibm-cloud-network_acl)
- [security_group](#ibm-cloud-security_group)
- [vsi](#ibm-cloud-vsi)
- [transit_gateway](#ibm-cloud-transit_gateway)
- [nfs_server](#ibm-cloud-nfs_server)
- [serviceid](#serviceid)
- [cos](#cos)

### IBM Cloud `provider`

Defines the provider that Terraform will use for managing the IBM Cloud assets.

```
provider:
- name: ibm
  region: eu-de
```

#### Property explanation

| Property | Description                  | Mandatory | Allowed values       |
| -------- | ---------------------------- | --------- | -------------------- |
| name     | Name of the provider cluster | No        | ibm                  |
| region   | Region to connect to         | Yes       | Any IBM Cloud region |

### IBM Cloud `resource_group`

The resource group is for cloud asset grouping purposes. You can define multiple resource groups in your IBM cloud account to group the provisioned assets. If you do not need to group your assets, choose `default`.

```
resource_group:
- name: default
```

#### Property explanation

| Property | Description                         | Mandatory | Allowed values |
| -------- | ----------------------------------- | --------- | -------------- |
| name     | Name of the existing resource group | Yes       |                |

### IBM Cloud `ssh_keys`

SSH keys to connect to VSIs. If you have Virtual Server Instances in your VPC, you will need an SSH key to connect to them. SSH keys defined here will be looked up in the vault and created if they don't exist already.

```
ssh_keys:
- name: vsi-access
  managed: True
```

#### Property explanation

| Property | Description                                                   | Mandatory | Allowed values        |
| -------- | ------------------------------------------------------------- | --------- | --------------------- |
| name     | Name of the SSH key in IBM Cloud                              | Yes       |                       |
| managed  | Determines if the SSH key will be created if it doesn't exist | No        | True (default), False |

### IBM Cloud `security_rule`

Defines the services (or ports) which are allowed within the context of a VPC and/or VSI.

```
security_rule:
- name: https
  tcp: {port_min: 443, port_max: 443}
- name: ssh
  tcp: {port_min: 22, port_max: 22}
```

#### Property explanation

| Property | Description                                                 | Mandatory  | Allowed values                 |
| -------- | -------------------------------------------------------     | -----------| ------------------------------ |
| name     | Name of the security rule                                   | Yes        |                                |
| tcp      | Range of tcp ports (`port_min` and `port_max`) to allow     | No         | 1-65535                        | 
| udp      | Range of udp ports (`port_min` and `port_max`) to allow     | No         | 1-65535                        |
| icmp     | ICMP Type and Code for IPv4 (`code` and `type`) to allow    | No         | 1-255 for code, 1-254 for type |

### IBM Cloud `vpc`

Defines the virtual private cloud which groups the provisioned objects (including VSIs and OpenShift cluster).

```
vpc:
- name: sample
  allow_inbound: ['ssh', 'https']
  classic_access: false
```

#### Property explanation

| Property      | Description                                                                                                                                                              | Mandatory | Allowed values            |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- | ------------------------- |
| name          | Name of the Virtual Private Cloud                                                                                                                                        | Yes       |                           |
| managed       | Controls whether the VPC is managed. The default is `True`. Only set to `False` if the VPC is not managed but only referenced by other objects such as transit gateways. | No        | True (default), False     |
| allow_inbound | Security rules which are allowed for inbound traffic                                                                                                                     | No        | Existing `security_rule`  |
| classic_access| Connect VPC to IBM Cloud classic infratructure resources                                                                                                                 | No        | false (default), true     |

### IBM Cloud `address_prefix`

Defines the zones used within the VPC, along with the subnet the addresses will be issued for.

```
- name: sample-zone-1
  vpc: sample
  zone: eu-de-1
  cidr: 10.27.0.0/26
- name: sample-zone-2
  vpc: sample
  zone: eu-de-2
  cidr: 10.27.0.64/26
- name: sample-zone-3
  vpc: sample
  zone: eu-de-3
  cidr: 10.27.0.128/26
```

#### Property explanation

| Property | Description                                          | Mandatory              | Allowed values  |
| -------- | ---------------------------------------------------- | ---------------------  | --------------  |
| name     | Name of the zone                                     | Yes                    |                 |
| zone     | Zone in the IBM Cloud                                | Yes                    |                 |
| cidr     | Address range that IPs in this zone will fall into   | Yes                    |                 |
| vpc      | Virtual Private Cloud this address prefix belongs to | Yes, inferred from vpc | Existing `vpc`  |

### IBM Cloud `subnet`

Defines the subnet that Virtual Server Instances and ROKS compute nodes will be attached to.

```
subnet:
- name: sample-subnet-zone-1
  address_prefix: sample-zone-1
  ipv4_cidr_block: 10.27.0.0/26
  zone: eu-de-1
  vpc: sample
  network_acl: sample-acl
```

#### Property explanation

| Property        | Description                                          | Mandatory                                 | Allowed values                     |
| --------------- | ---------------------------------------------------- | ---------------------------------------   | ---------------------------------- |
| name            | Name of the subnet                                   | Yes                                       |                                    |
| zone            | Zone this subnet belongs to                          | Yes, inferred from address_prefix->zone   |                                    |
| ipv4_cidr_block | Address range that IPs in this subnet will fall into | Yes, inferred from address_prefix->cidr   | Range of subrange of zone          |
| address_prefix  | Zone of the address prefix definition                | Yes, inferred from address_prefix         | Existing `address_prefix`          |
| vpc             | Virtual Private Cloud this subnet prefix belongs to  | Yes, inferred from address_prefix->vpc    | Existing `vpc`                     |
| network_acl     | Reference to the network access control list protecting this subnet | No                         |                                    |

### IBM Cloud `network_acl`

Defines the network access control list to be associated with subnets to allow or deny traffic from or to external connections. The rules are processed in sequence per direction. Rules that appear higher in the list will be processed first.

```
network_acl:
- name: "{{ env_id }}-acl"
  vpc_name: "{{ env_id }}"
  rules:
  - name: inbound-ssh
    action: allow               # Can be allow or deny
    source: "0.0.0.0/0"
    destination: "0.0.0.0/0"
    direction: inbound
    tcp:
      source_port_min: 1        # optional
      source_port_max: 65535    # optional
      dest_port_min: 22         # optional
      dest_port_max: 22         # optional
  - name: output-udp
    action: deny                # Can be allow or deny
    source: "0.0.0.0/0"
    destination: "0.0.0.0/0"
    direction: outbound
    udp:
      source_port_min: 1        # optional
      source_port_max: 65535    # optional
      dest_port_min: 1000       # optional
      dest_port_max: 2000       # optional
  - name: output-icmp
    action: allow               # Can be allow or deny
    source: "0.0.0.0/0"
    destination: "0.0.0.0/0"
    direction: outbound
    icmp:
      code: 1
      type: 1
```

#### Property explanation

| Property        | Description                                          | Mandatory               | Allowed values            |
| --------------- | ---------------------------------------------------- | ----------------------- | ------------------------- |
| name            | Name of the network access control liet              | Yes                     |                           |
| vpc_name        | Virtual Private Cloud this network ACL belongs to    | Yes                     |                           |
| rules           | Rules to be applied, every rule is an entry in the list | Yes                  |                           |
| rules.name      | Unique name of the rule                              | Yes                     |                           |
| rules.action    | Defines whether the traffic is allowed or denied     | Yes                     | allow, deny               |
| rules.source    | Source address range that defines the rule           | Yes                     |                           |
| rules.destination | Destination address range that defines the rule    | Yes                     |                           |
| rules.direction | Inbound or outbound direction of the traffic         | Yes                     | inbound, outbound         |
| rules.tcp       | Rule for TCP traffic                                 | No                      |                           |
| rules.tcp.source_port_min | Low value of the source port range         | No, default=1           | 1-65535                   |
| rules.tcp.source_port_max | High value of the source port range        | No, default=65535       | 1-65535                   |
| rules.tcp.dest_port_min   | Low value of the destination port range    | No, default=1           | 1-65535                   |
| rules.tcp.dest_port_max | High value of the destination port range   | No, default=65535       | 1-65535                   |
| rules.udp       | Rule for UDP traffic                                 | No                      |                           |
| rules.udp.source_port_min | Low value of the source port range         | No, default=1           | 1-65535                   |
| rules.udp.source_port_max | High value of the source port range        | No, default=65535       | 1-65535                   |
| rules.udp.dest_port_min   | Low value of the destination port range    | No, default=1           | 1-65535                   |
| rules.udp.dest_port_max | High value of the destination port range   | No, default=65535       | 1-65535                   |
| rules.icmp      | Rule for ICMP traffic                                | No                      |                           |
| rules.icmp.code | ICMP traffic code                                    | No, default=all         | 0-255                     |
| rules.icmp.type | ICMP traffic type                                    | No, default=all         | 0-254                     |


### IBM Cloud `vsi`

Defines a Virtual Server Instance within the VPC.

```
vsi:
- name: sample-bastion
  infrastructure:
    type: vpc
    keys:
    - "vsi-access"
    image: ibm-redhat-8-3-minimal-amd64-3
    subnet: sample-subnet-zone-1
    primary_ipv4_address: 10.27.0.4
    public_ip: True
    vpc_name: sample
    zone: eu-de-3
```

#### Property explanation

| Property                            | Description                                               | Mandatory                         | Allowed values                              |
| ----------------------------------- | --------------------------------------------------------- | ------------------------------    | ------------------------------------------- |
| name                                | Name of the Virtual Server Instance                       | Yes                               |                                             |
| infrastructure                      | Infrastructure attributes                                 | Yes                               |                                             |
| infrastructure.type                 | Infrastructure type                                       | Yes                               | vpc                                         |
| infrastructure.allow_ip_spoofing    | Decide if IP spoofing is allowed for the interface or not | No                                | False (default), True                       |
| infrastructure.keys                 | List of SSH keys to attach to the VSI                     | Yes, inferred from ssh_keys       | Existing `ssh_keys`                         |
| infrastructure.image                | Operating system image to be used                         | Yes                               | Existing image in IBM Cloud                 |
| infrastructure.profile              | Server profile to be used, for example cx2-2x4            | Yes                               | Existing profile in IBM Cloud               |
| infrastructure.subnet               | Subnet the VSI will be connected to                       | Yes, inferred from sunset         | Existing `subnet`                           |
| infrastructure.primary_ipv4_address | IP v4 address that will be assigned to the VSI            | No                                | If specified, address in the `subnet` range |
| infrastructure.public_ip            | Must a public IP address be attached to this VSI?         | No                                | False (default), True                       |
| infrastructure.vpc_name             | Virtual Private Cloud this VSI belongs to                 | Yes, inferred from vpc            | Existing `vpc`                              |
| infrastructure.zone                 | Zone the VSI will be plaed into                           | Yes, inferred from subnet->zone   |                                             |

### IBM Cloud `transit_gateway`

Connects one or more VPCs to each other.

```
transit_gateway:
- name: sample-tgw
  location: eu-de
  connections:
  - vpc: other-vpc
  - vpc: sample
```

#### Property explanation

| Property       | Description                                                                                                                                                                                                                            | Mandatory | Allowed values |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | -------------- |
| name           | Name of the transit gateway                                                                                                                                                                                                            | Yes       |                |
| location       | IBM Cloud location of the transit gateway                                                                                                                                                                                              | Yes       |                |
| connections    | Defines which VPCs must be included in the transit gateway                                                                                                                                                                             | Yes       |                |
| connection.vpc | Defines the VPC to include. Every VPC must exist in the configuration, even if not managed by this configuration. When referencing an existing VPC, make sure that there is a `vpc` object of that name with `managed` set to `False`. | Yes       | Existing `vpc` |

### IBM Cloud `nfs_server`

Defines a Virtual Server Instance within the VPC that will be used as an NFS server.

```
nfs_server:
- name: sample-nfs
  infrastructure:
    type: vpc
    vpc_name: sample
    subnet: sample-subnet-zone-1
    zone: eu-de-1
    primary_ipv4_address: 10.27.0.5
    image: ibm-redhat-8-3-minimal-amd64-3
    profile: cx2-2x4
    bastion_host: sample-bastion
    storage_folder: /data/nfs
    storage_profile: 10iops-tier
    keys:
      - "sample-nfs-provision"
```

#### Property explanation

| Property                            | Description                                                                 | Mandatory                       | Allowed values                              |
|-------------------------------------|-----------------------------------------------------------------------------|---------------------------      |---------------------------------------------|
| name                                | Name of the Virtual Server Instance                                         | Yes                             |                                             |
| infrastructure                      | Infrastructure attributes                                                   | Yes                             |                                             |
| infrastructure.image                | Operating system image to be used                                           | Yes                             | Existing image in IBM Cloud                 |
| infrastructure.profile              | Server profile to be used, for example cx2-2x4                              | Yes                             | Existing profile in IBM Cloud               |
| infrastructure.type                 | Type of infrastructure for NFS servers to                                   | Yes                             | vpc                                         |
| infrastructure.vpc_name             | Virtual Private Cloud this VSI belongs to                                   | Yes, inferred from vpc          | Existing `vpc`                              |
| infrastructure.subnet               | Subnet the VSI will be connected to                                         | Yes, inferred from subnet       | Existing `subnet`                           |
| infrastructure.zone                 | Zone the VSI will be plaed into                                             | Yes, inferred from subnet->zone |                                             |
| infrastructure.primary_ipv4_address | IP v4 address that will be assigned to the VSI                              | No                              | If specified, address in the `subnet` range |
| infrastructure.bastion_host         | Specify the VSI of the bastion to reach this NFS server                     | No                              |                                             |
| infrastructure.storage_profile      | Storage profile that will be used                                           | Yes                             | 3iops-tier, 5iops-tier, 10iops-tier         |
| infrastructure.volume_size_gb       | Size of the NFS server data volume                                          | Yes                             |                                             |
| infrastructure.storage_folder       | Folder that holds the data, this will be mounted from the NFS storage class | Yes                             |                                             |
| infrastructure.keys                 | List of SSH keys to attach to the NFS server VSI                            | Yes, inferred from ssh_keys     | Existing `ssh_keys`                         |
| infrastructure.allow_ip_spoofing    | Decide if IP spoofing is allowed for the interface or not                   | No                              | False (default), True                       |

### IBM Cloud `cos`

Defines a IBM Cloud Cloud Object Storage instance and allows to create buckets.

```
cos:
- name: {{ env_id }}-cos
  plan: standard
  location: global
  serviceids:
  - name: {{ env_id }}-cos-serviceid
    roles: ["Manager", "Viewer", "Administrator"]
  buckets:
  - name: bucketone6c9d6840
    cross_region_location: eu
```

#### Property explanation

| Property                        | Description                                                                                           | Mandatory                                    | Allowed values                                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| name                            | Name of the serviceid                                                                                 | Yes                                          |                                                                                                      |
| plan                            | short description of the serviceid                                                                    | Yes                                          |                                                                                                      |
| location                        | collection of servicekeys that should be created for the parent serviceid                             | Yes                                          |                                                                                                      |
| serviceids                      | Collection of references to defined seriveids                                                         | No                                           |                                                                                                      |
| serviceids.name                 | Name of the serviceid                                                                                 | Yes                                          |                                                                                                      |
| serviceids.roles                | An array of strings to define which role should be granted to the serviceid                           | Yes                                          |                                                                                                      |
| buckets                         | Collection of buckets that should be created inside the cos instance                                  | No                                           |                                                                                                      |
| buckets[].name                  | Name of the bucket                                                                                    | No                                           |                                                                                                      |
| buckets[].storage_class         | Storage class of the bucket                                                                           | No                                           | standard (default), vault, cold, flex, smart                                                         |
| buckets[].endpoint_type         | Endpoint type of the bucket                                                                           | No                                           | public (default), private                                                                            |
| buckets[].cross_region_location | If you use this parameter, do not set single_site_location or region_location at the same time.       | Yes (one of)                                 | us, eu, ap                                                                                           |
| buckets[].region_location       | If you set this parameter, do not set single_site_location or cross_region_location at the same time. | Yes (one of)                                 | au-syd, eu-de, eu-gb, jp-tok, us-east, us-south, ca-tor, jp-osa, br-sao                              |
| buckets[].single_site_location  | If you set this parameter, do not set region_location or cross_region_location at the same time.      | Yes (one of)                                 | ams03, che01, hkg02, mel01, mex01, mil01, mon01, osl01, par01, sjc04, sao01, seo01, sng01, and tor01 |


### `serviceid`

Defines a iam_service_id that can be granted several role based accesss right via attaching iam_policies to it.

```
serviceid:
- name: sample-serviceid
  description: to access ibmcloud services from external
  servicekeys:
  - name: primarykey
```

#### Property explanation

| Property         | Description                                                               | Mandatory | Allowed values |
| ---------------- | ------------------------------------------------------------------------- | --------- | -------------- |
| name             | Name of the serviceid                                                     | Yes       |                |
| description      | short description of the serviceid                                        | No        |                |
| servicekeys      | collection of servicekeys that should be created for the parent serviceid | No        |                |
| servicekeys.name | Name of the servicekey                                                    | Yes       |                |

## Microsoft Azure

For Microsoft Azure, the following object type is supported:

- [azure](#azure)

### Azure

Defines an infrastructure configuration onto which OpenShift will be provisioned.

```
azure:
- name: sample
  resource_group:
    name: sample
    location: westeurope
  vnet:
    name: vnet
    address_space: 10.0.0.0/22
  control_plane:
    subnet:
      name: control-plane-subnet
      address_prefixes: 10.0.0.0/23
  compute:
    subnet:
      name: compute-subnet
      address_prefixes: 10.0.2.0/23
```

#### Properties explanation

| Property                              | Description                                                                              | Mandatory | Allowed values                                                                                                                                               |
| ------------------------------------- | ---------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| name                                  | Name of the `azure` definition object, will be referenced by `openshift`             | Yes       |                                                                                                                                                              |
| resource_group                        | Resource group attributes                                                                | Yes       |                                                                                                                                                              |
| resource_group.name                   | Name of the resource group (will be provisioned)                                         | Yes       | unique value, it must not exist                                                                                                                              |
| resource_group.location               | Azure location                                                                           | Yes       | to pick a different location, run: `az account list-locations -o table`                                                                                      |
| vnet                                  | Virtual network attributes                                                               | Yes       |                                                                                                                                                              |
| vnet.name                             | Name of the virtual network                                                              | Yes       |                                                                                                                                                              |
| vnet.address_space                    | Address space of the virtual network                                                     | Yes       |                                                                                                                                                              |
| control_plane                         | Control plane (master) nodes attributes                                                  | Yes       |                                                                                                                                                              |
| control_plane.subnet                  | Control plane nodes subnet attributes                                                    | Yes       |                                                                                                                                                              |
| control_plane.subnet.name             | Name of the control plane nodes subnet                                                   | Yes       |                                                                                                                                                              |
| control_plane.subnet.address_prefixes | Address prefixes of the control plane nodes subnet (divided by a `,` comma, if relevant) | Yes       |                                                                                                                                                              |
| control_plane.vm                      | Control plane nodes virtual machine attributes                                           | Yes       |                                                                                                                                                              |
| control_plane.vm.size                 | Virtual machine size (aka flavour) of the control plane nodes                            | Yes       | `Standard_D8s_v3`, `Standard_D16s_v3`, `Standard_D32s_v3`                                                                                                    |
| compute                               | Compute (worker) nodes attributes                                                        | Yes       |                                                                                                                                                              |
| compute.subnet                        | Compute nodes subnet attributes                                                          | Yes       |                                                                                                                                                              |
| compute.subnet.name                   | Name of the compute nodes subnet                                                         | Yes       |                                                                                                                                                              |
| compute.subnet.address_prefixes       | Address prefixes of the compute nodes subnet (divided by a `,` comma, if relevant)       | Yes       |                                                                                                                                                              |
| compute.vm                            | Compute nodes virtual machine attributes                                                 | Yes       |                                                                                                                                                              |
| compute.vm.size                       | Virtual machine size (aka flavour) of the compute nodes                                  | Yes       | See the full list of [supported virtual machine sizes](https://docs.microsoft.com/en-us/azure/openshift/support-policies-v4#supported-virtual-machine-sizes) |
| compute.vm.disk_size_gb               | Disk size in GBs of the compute nodes virtual machine                                    | Yes       | minimum value is 128                                                                                                                                         |
| compute.vm.count                      | Number of compute nodes virtual machines                                                 | Yes       | minimum value is 3                                                                                                                                           |

## Amazon

For Amazon AWS, the following object types are supported:

- [nfs_server](#aws--efs-server-nfs_server)

### AWS EFS Server `nfs_server`

Defines a new Elastic File Storage (EFS) service that is connected to the OpenShift cluster within the same VPC. The file storage will be used as the back-end for the `efs-nfs-client` OpenShift storage class.

```
nfs_server:
- name: sample-elastic
  infrastructure:
    aws_region: eu-west-1
```

#### Property explanation

| Property                      | Description                                                                 | Mandatory | Allowed values |
| ----------------------------- | --------------------------------------------------------------------------- | --------- | -------------- |
| name                          | Name of the EFS File System service to be created                           | Yes       |                |
| infrastructure                | Infrastructure attributes                                                   | Yes       |                |
| infrastructure.aws_region     | AWS region where the storage will be provisioned                            | Yes       |                |


## vSphere

For vSphere, the following object types are supported:

- [vsphere](#vsphere-vsphere)
- [vm_definition](#vsphere-vm_definition)
- [nfs_server](#vsphere-nfs_server)

### vSphere `vsphere`

Defines the vSphere vCenter onto which OpenShift will be provisioned.

```
vsphere:
- name: sample
  vcenter: 10.99.92.13
  datacenter: Datacenter1
  datastore: Datastore1
  cluster: Cluster1
  network: "VM Network"
  folder: /Datacenter1/vm/sample
```

#### Property explanation

| Property      | Description                                                                 | Mandatory | Allowed values |
| ------------- | --------------------------------------------------------------------------- | --------- | -------------- |
| name          | Name of the vSphere definition, will be referenced by `openshift`           | Yes       |                |
| vcenter       | Host or IP address of the vSphere Center                                    | Yes       |                |
| datacenter    | vSphere Data Center to be used for the virtual machines                     | Yes       |                |
| datastore     | vSphere Datastore to be used for the virtual machines                       | Yes       |                |
| cluster       | vSphere cluster to be used for the virtual machines                         | Yes       |                |
| resource_pool | vSphere resource pool                                                       | No        |                |
| network       | vSphere network to be used for the virtual machines                         | Yes       |                |
| folder        | Fully qualified folder name into which the OpenShift cluster will be placed | Yes       |                |

### vSphere `vm_definition`

Defines the virtual machine properties to be used for the control-plane nodes and compute nodes.

```
vm_definition:
- name: control-plane
  vcpu: 8
  memory_mb: 32768
  boot_disk_size_gb: 100
- name: compute
  vcpu: 16
  memory_mb: 65536
  boot_disk_size_gb: 200
  # Optional overrides for vsphere properties
  # datastore: Datastore1
  # network: "VM Network"
```

#### Property explanation

| Property          | Description                                                  | Mandatory | Allowed values |
| ----------------- | ------------------------------------------------------------ | --------- | -------------- |
| name              | Name of the VM definition, will be referenced by `openshift` | Yes       |                |
| vcpu              | Number of virtual CPUs to be assigned to the VMs             | Yes       |                |
| memory_mb         | Amount of memory in MiB of the virtual machines              | Yes       |                |
| boot_disk_size_gb | Size of the virtual machine boot disk in GiB                 | Yes       |                |
| datastore         | vSphere Datastore to be used for the virtual machines, overrides `vsphere.datastore` |  No       |  |
| network           | vSphere network to be used for the virtual machines, overrides `vsphere.network`      | No       |  |

### vSphere `nfs_server`

Defines an existing NFS server that will be used for the OpenShift NFS storage class.

```
nfs_server:
- name: sample-nfs
  infrastructure:
    host_ip: 10.99.92.31
    storage_folder: /data/nfs
```

#### Property explanation

| Property                      | Description                                                                 | Mandatory | Allowed values |
| ----------------------------- | --------------------------------------------------------------------------- | --------- | -------------- |
| name                          | Name of the NFS server                                                      | Yes       |                |
| infrastructure                | Infrastructure attributes                                                   | Yes       |                |
| infrastructure.host_ip        | Host or IP address of the NFS server                                        | Yes       |                |
| infrastructure.storage_folder | Folder that holds the data, this will be mounted from the NFS storage class | Yes       |                |
