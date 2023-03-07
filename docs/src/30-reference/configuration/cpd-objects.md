# Configuration objects

All objects used by the Cloud Pak Deployer are defined in a yaml format in files in the `config` directory. You can create a single yaml file holding all objects, or group objects in individual yaml files. At deployment time, all yaml files in the `config` directory are merged.

To make it easier to navigate the different object types, they have been groups in different tabs. You can also use the index below to find the definitions.

### Configuration
* [Global configuration](cpd-global-config.md)
* [Vault configuration](vault.md)

### Infrastructure

* [Infrastructure objects](infrastructure.md)
* Provider
* Resource groups
* Virtual Private Clouds (VPCs)
* Security groups
* Security rules
* Address prefixes
* Subnets
* Floating ips
* Virtual Server Instances (VSIs)
* NFS Servers
* SSH keys
* Transit Gateways

### [OpenShift object types](openshift.md)
* [Existing OpenShift](openshift.md#existing-openshift)
* [OpenShift on IBM Cloud](openshift.md#openshift-on-ibm-cloud-roks)
* [OpenShift on AWS - ROSA](openshift.md#openshift-on-aws---rosa)
* [OpenShift on AWS - self-managed](openshift.md#openshift-on-aws---self-managed)
* [OpenShift on Microsoft Azure (ARO)](openshift.md#openshift-on-microsoft-azure-aro)
* [OpenShift on vSphere](openshift.md#openshift-on-vsphere)

### [Cloud Paks and related object types](cloud-pak.md)

* [Cloud Pak for Data - cp4d](cloud-pak.md#cp4d)
* [Cloud Pak for Integration - cp4d](cloud-pak.md#cp4i)
* [Cloud Pak for Watson AIOps - cp4d](cloud-pak.md#cp4waiops)
* [Private registry](private-registry.md)

### [Cloud Pak for Data Cartridges object types](cp4d-cartridges.md)

* [Cloud Pak for Data Control Plane - cpd_platform](cp4d-cartridges.md#cpd_platform)
* [Cloud Pak for Data Cognos Analytics - ca](cp4d-cartridges.md#ca)
* [Cloud Pak for Data Db2 OLTP - db2oltp](cp4d-cartridges.md#db2oltp)
* [Cloud Pak for Data Watson Studio - ws](cp4d-cartridges.md#ws)
* [Cloud Pak for Data Watson Machine Learning - wml](cp4d-cartridges.md#wml)