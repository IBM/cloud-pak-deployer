---
title: Configure infrastructure
tabs: ['Overview', 'Validate', 'Prepare', 'Provision-infra', 'Configure-infra', 'Install-cloud-pak', 'Configure-cloud-pak', 'Deploy-assets', 'Smoke-tests']
---

# Configure infrastructure

This stage focuses on the configuration of the provisioned infrastructure.

## Configure infrastructure for IBM Cloud

### Configure the VPC bastion server(s)
In a configuration scenario where NFS is used for OpenShift storage, the NFS server must be provisioned as a VSI within the VPC that contains the OpenShift cluster. It is best practice to shield off the NFS server from the outside world by using a jump host (bastion) to access it.

This steps configures the bastion host which has a public IP address to serve as a jump host to access other servers and services within the VPC.

### Configure the VPC NFS server(s)
Configures the NFS server using the specs in the `nfs_server` configuration object(s). It installs the required packages and sets up the NFSv4 service. Additionally, it will format the empty volume as `xfs` and export it so it can be used by the `managed-nfs-storage` storage class in the OpenShift cluster.

### Configure the OpenShift storage classes
This steps takes care of configuring the storage classes in the OpenShift cluster. Storage classes are an abstraction of the underlying physical and virtual storage. When run, it processes the `openshift_storage` elements within the current `openshift` configuration object.

Two types of storage classes can be automatically created and configured:

#### NFS Storage
Creates the `managed-nfs-storage` OpenShift storage class using the specified `nfs_server_name` which references an `nfs_server` configuration object.

#### ODF Storage
Activates the ROKS cluster's OpenShift Data Foundation add-on to install the operator into the cluster. Once finished with the preparation, the `OcsCluster` OpenShift object is created to provision the storage cluster. As the backing storage the `ibmc-vpc-block-metro-10iops-tier` storage class is used, which has the appropriate IO characteristics for the Cloud Paks.

!!! info
    Both NFS and ODF storage classes can be created but only 1 storage class of each type can exist in the cluster at the moment. If more than one storage class of the same type is specified, the configuration will fail.