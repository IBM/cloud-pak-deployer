Role: prepare_project
=========

Create the OpenShift Project
Extract the IBM Container Registry (ICR) key from the Vault, ICR_API_KEY
If the key does not exist, generate key for the icr saas_service and store its key value in the vault
Patch the OpenShift project with the pull secret of the ICR_API_KEY to allow deployment to pull from the ICR during installation of CP4D

Requirements
------------


Role Variables
--------------


Dependencies
------------


Example Playbook
----------------


License
-------


Author Information
------------------
