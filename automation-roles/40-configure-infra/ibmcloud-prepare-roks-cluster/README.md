Role: roks-cluster
=========

Login to the OpenShift ROKS cluster
Validation/Creation NFS storage class
Create DaemonSet in OpenShift kernel-optimization

Requirements
------------

Prior to calling this role the IBM Cloud API key must be retrieved from the Vault and is set to ibmcloud_api_key

role:
- login_ocp
  Login to the Openshift ROKS cluster using the ibmcloud_api_key retrieved from the vault

Role Variables
--------------

ibmcloud_api_key: Retrieved from IBM Vault
ibm_cloud_region: Default set to 'eu-de'

Dependencies
------------

None

----------------

License
-------


Author Information
------------------
