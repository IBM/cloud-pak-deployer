# IBM Cloud ROKS on VPC with NFS storage class and Cloud Pak for Data
This is a sample configuration for ROKS on IBM Cloud, provisioned in a VPC. All infrastructure, OpenShift and Cloud Pak for Data are managed by the deployer and deployment requires nothing but an IBM Cloud API key and a Cloud Pak entitlement key.

![Picture of the environment](./sample-roks-vpc-nfs-cp4d.png)

## Infrastructure

### Virtual Private Cloud on IBM Cloud
The Virtual Private Cloud (VPC) contains all of the assets needed that make up this configuration.

### Zones with address prefixes
The sample configuration is made up of 3 availability zones, each with its own address prefix. Zones 1 and 2 have a netmask of `/26`, which means each zone can provide up to 59 IP addresses (the first 5 addresses in the CIDR block are reserved by IBM Cloud). Zone 3 has a netmask of `/25`, which means it can address 123 IP addresses (128-5).

### Subnets
4 subnets are created. Zones 1 and 2 have a single subnet which span the entire IP address block. Zone 3 is split up into 2 subnets, one for OpenShift workers (zone-3) and one for shared virtual servers such as the bastion and the NFS server.

### Virtual Server Instances
A bastion is provisioned to serve as a jump host from the internet. It prevents the NFS server from having to have a public IP address. The NFS server can only be reached by using the bastion as the jump host and with the SSH private key that is provisioned too.

The NFS server provides the back-end storage for the `managed-nfs-storage` storage class in OpenShift. Due to throughput limitations and the fact that NFS cannot serve true block storage, not all cartridges support this storage type. Please check the cartridge in question before you install to determine if NFS is supported. By default a 1 TB volume is with a throughput of 10k IOPS is added to the NFS server.

## OpenShift
An OpenShift cluster with the specified version (4.6) is provisioned inside the VPC and across subnets 1, 2 and 3. In the sample configuration, the `managed-nfs-storage` storage class is created, referencing the NFS server that is provisioned in the VPC.

## Cloud Pak for Data
Cloud Pak for Data 4.0 is installed in OpenShift project `zen-40`, pulling images from the IBM entitled registry and referencing the NFS storage class in OpenShift.

### Cartridges
The sample configuration holds a list of cartridges which will be installed. You can control whether cartridges will be installed by commenting or uncommenting the appropriate blocks. Please ensure that the cartridge elements are aligned (hyphens must be aligned with hyphens and properties with properties).

By default, the following cartridges will be installed:
* Cloud Pak Foundational Services (is installed as part of the Cloud Pak for Data control plane)
* Cloud Pak for Data control plane (mandatory)
* Watson Studio
* Watson Machine Learning
* Watson Knowledge Catalog