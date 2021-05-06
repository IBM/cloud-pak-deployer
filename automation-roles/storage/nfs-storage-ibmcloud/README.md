Role: nfs_storage
=========

Using the file-storage entry in the saas-services, authorize all hosts of the OpenShift cluster for the NFS Storage.
Create the Dynamic NFS provisioner on OpenShift to be used by Cloud Pak for Data as its StorageClass

Requirements
------------

Prior to calling this role the IBM Cloud API key must be retrieved from the Vault and is set to ibmcloud_api_key
Prior to calling this role the saas_services fact must be populated

Role Variables
--------------

ibmcloud_api_key: Retrieved from IBM Vault
saas_services: From role preprocess to contruct the automation yaml structure

Dependencies
------------

None

----------------

License
-------


Author Information
------------------
