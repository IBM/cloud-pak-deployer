# Deployment process overview

![Deployment process overview](images/provisioning-process.png)

When running the Cloud Pak Deployer (`cp-deploy env apply`), a series of pre-defined stages are followed to arrive at the desired end-state.

## [10 - Validation](../../../30-reference/process/validate)
In this stage, the following activities are executed:

* Is the specified cloud platform in the inventory file supported?
* Are the mandatory variables defined?
* Can the deployer connect to the specified vault?

## [20 - Prepare](../../../30-reference/process/prepare)
In this stage, the following activities are executed:

* Read the configuration files from the `config` directory
* Replace variable placeholders in the configuration with the extra parameters passed to the `cp-deploy` command
* Expand the configuration with defaults from the `defaults` directory
* Run the "linter" to check the object attributes in the configuration and their relations
* Generate the Terraform scripts to provision the infrastructure (IBM Cloud only)
* Download all CLIs needed for the selected cloud platform and cloud pak(s), if not air-gapped

## [30 - Provision infra](../../../30-reference/process/provision-infra)
In this stage, the following activities are executed:

* Run Terraform to create or change the infrastructure components for IBM cloud
* Run the OpenShift installer-provisioned infrastructure (IPI) installer for AWS (ROSA), Azure (ARO) or vSphere

## [40 - Configure infra](../../../30-reference/process/configure-infra)
In this stage, the following activities are executed:

* Configure the VPC bastion and NFS server(s) for IBM Cloud
* Configure the OpenShift storage classes or test validate the existing storege classes if an existing OpenShift cluster is used
* Configure OpenShift logging

## [50 - Install Cloud Pak](../../../30-reference/process/install-cloud-pak)
In this stage, the following activities are executed:

* Create the IBM Container Registry namespace for IBM Cloud
* Connect to the specified image registry and create ImageContentSourcePolicy
* Prepare OpenShift cluster for Cloud Pak for Data installation
* Mirror images to the private registry
* Install Cloud Pak for Data control plane
* Configure Foundational Services license service
* Install specified Cloud Pak for Data cartridges

## [60 - Configure Cloud Pak](../../../30-reference/process/configure-cloud-pak)
In this stage, the following activities are executed:

* Add OpenShift signed certificate to Cloud Pak for Data web server when on IBM Cloud
* Configure LDAP for Cloud Pak for Data
* Configure SAML authentication for Cloud Pak for Data
* Configure auditing for Cloud Pak for Data
* Configure instance for the cartridges (Analytics engine, Db2, Cognos Analytics, Data Virtualization, ...)
* Configure instance authorization using the LDAP group mapping

## [70 - Deploy Assets](../../../30-reference/process/deploy-assets)

* Configure Cloud Pak for Data monitors
* Install Cloud Pak for Data assets

## [80 - Smoke Tests](../../../30-reference/process/smoke-tests)
In this stage, the following activities are executed:

* Show the Cloud Pak for Data URL and admin password