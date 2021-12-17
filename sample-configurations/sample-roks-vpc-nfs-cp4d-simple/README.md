# IBM Cloud ROKS on VPC with NFS storage class and Cloud Pak for Data
This is a sample configuration for ROKS on IBM Cloud, provisioned in a VPC with NFS storage. Optionally, you can also configure OpenShift Container Storage on 3 dedicated nodes within the ROKS cluster. All infrastructure, OpenShift and Cloud Pak for Data are managed by the deployer and deployment requires nothing but an IBM Cloud API key and a Cloud Pak entitlement key.

<InlineNotification kind="warning">
This configuration is not highly available and has several single points of failure (SPoF). The NFS server is a single server and its storage is not replicated. If the NFS server is faulty, the applications (Cloud Pak) on the cluster will no longer work and have to be restored or reinstalled. Even when using OpenShift Container Storage (deployed on 3 nodes), there is a still a SPoF because all OCS workers are deployed in the same subnet and availability zone.
</InlineNotification>

![Picture of the environment](./sample-roks-vpc-nfs-cp4d-simple.png)

## Infrastructure

### Virtual Private Cloud on IBM Cloud
The Virtual Private Cloud (VPC) contains all of the assets needed that make up this configuration.

### Zones with address prefixes
The sample configuration is made up of 1 availability zone with a netmask of `/24`.

### Subnets
1 subnet is created which spans the entire IP address block and holds the ROKS cluster, the bastion and the NFS server.

### Virtual Server Instances
A bastion is provisioned to serve as a jump host from the internet. It prevents the NFS server from having to have a public IP address. The NFS server can only be reached by using the bastion as the jump host and with the SSH private key that is provisioned too.

The NFS server provides the back-end storage for the `managed-nfs-storage` storage class in OpenShift. Due to throughput limitations and the fact that NFS cannot serve true block storage, not all cartridges support this storage type. Please check the cartridge in question before you install to determine if NFS is supported. By default a 1 TB volume is with a throughput of 10k IOPS is added to the NFS server.

## OpenShift
An OpenShift cluster with the specified version (4.8) is provisioned inside the VPC. In the sample configuration, the `managed-nfs-storage` storage class is created, referencing the NFS server that is provisioned in the VPC. Optionallym OpenShift Container Storage (OpenShift Data Foundation) is deployed on 3 dedicated storage/worker nodes. As part of the OCS provisioning, 2 storage classes are created: `ocs-storagecluster-cephfs` for file storage and `ocs-storagecluster-ceph-rbd` for block storage.

## Cloud Pak for Data
Cloud Pak for Data 4.0 is installed in OpenShift project `zen-40`, pulling images from the IBM entitled registry and referencing the NFS storage class in OpenShift.

### Cartridges
The sample configuration holds a list of cartridges which will be installed. You can control whether cartridges will be installed by commenting or uncommenting the appropriate blocks. Please ensure that the cartridge elements are aligned (hyphens must be aligned with hyphens and properties with properties).

By default, the following cartridges will be installed:
* Cloud Pak Foundational Services (is installed as part of the Cloud Pak for Data control plane)
* Cloud Pak for Data control plane (mandatory)
* Watson Studio
* Watson Machine Learning