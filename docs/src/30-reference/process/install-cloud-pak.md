---
title: Install the Cloud Pak
tabs: ['Overview', 'Validate', 'Prepare', 'Provision-infra', 'Configure-infra', 'Install-cloud-pak', 'Configure-cloud-pak', 'Deploy-assets', 'Smoke-tests']
---

# Install the Cloud Pak(s)

This stage focuses on preparing the OpenShift cluster for installing the Cloud Pak(s) and then proceeds with the installation of Cloud Paks and the cartridges. The below documentation will start with a list of steps that will be executed for all Cloud Paks, then proceed with Cloud Pak specific activities. The execution of the steps may slightly differ from the sequence in the documentation.

Sections:

* [Remove obsolete Cloud Pak for Data instances](#remove-cloud-pak-for-data)
* [Prepare private image registry](#prepare-private-image-registry)
* [Install Cloud Pak for Data and cartridges](#install-cloud-pak-for-data-and-cartridges)

## Remove Cloud Pak for Data
Before going ahead with the mirroring of container images and installation of Cloud Pak for Data, the previous configuration (if any) is retrieved from the vault to determine if a Cloud Pak for Data instance has been removed. If a previously installed `cp4d` object no longer exists in the current configuration, its associated instance is removed from the OpenShift cluster.

First, the custom resources are removed from the OpenShift project. This happens with a grace period of 5 minutes. After the grace period has expired, OpenShift automatically forcefully deletes the custom resource and its associated definitions. Then, the control plane custom resource `Ibmcpd` is removed and finally the namespace (project). For the namespace deletion, a grace period of 10 minutes is applied.

## Prepare private image registry
When installing the Cloud Paks, images must be pulled from an image registry. All Cloud Paks support pulling images directly from the IBM Entitled Registry using the entitlement key, but there may be situations this is not possible, for example in air-gapped environents, or when images must be scanned for vulnerabilities before they are allowed to be used. In those cases, a private registry will have to be set up.

The Cloud Pak Deployer can mirror images to a private registry from the entitled registry. On IBM Cloud, the deployer is also capable of creating a namespace in the IBM Container Registry and mirror the images to that namespace.

When a private registry has been specified in the Cloud Pak entry (using the `image_registry_name` property), the necessary OpenShift configuration changes will also be made.

### Create IBM Container Registry namespace (IBM Cloud only)
If OpenShift is deployed on IBM Cloud (ROKS), the IBM Container Registry should be used as the private registry from which the images will be pulled. Images in the ICR are organized by namespace and can be accessed using an API key issued for a service account. If an `image_registry` object is specified in the configuration, this process will take care of creating the service account, then the API key and it will store the API key in the vault.

### Connect to the specified private image registry
If an image registry has been specified for the Cloud Pak using the `image_registry_name` property, the referenced `image_registry` entry is looked up in the configuration and the credentials are retrieved from the vault. Then the connection to the registry is tested by logging on.

## Install Cloud Pak for Data and cartridges

### Prepare OpenShift cluster for Cloud Pak installation
Cloud Pak for Data requires a number of cluster-wide settings:

* Create an `ImageContentSourcePolicy` if images must be pulled from a private registry
* Set the global pull secret with the credentials to pull images from the entitled or private image registry
* Create a `Tuned` object to set kernel semaphores and other properties of CoreOS containers being spun up
* Allow unsafe system controls in the Kubelet configuration
* Set PIDs limit and default ulimit for the CRI-O configuration

For all OpenShift clusters, except ROKS on IBM Cloud, these settings are applied using OpenShift configuration objects and then picked up by the Machine Config Operator. This operator will then apply the settings to the control plane and compute nodes as appropriate and reload them one by one.

To avoid having to reload the nodes more than once, the Machine Config Operator is paused before the settings are applied. After all setup, the Machine Config Operator is released and the deployment process will then wait until all nodes are ready with the configuration applied.

#### Prepare OpenShift cluster on IBM Cloud and IBM Cloud Satellite
As mentioned before, ROKS on IBM Cloud does not include the Machine Config Operator and would normally require the compute nodes to be reloaded (classic ROKS) or replaced (ROKS on VPC) to make the changes effective. While implementing this process, we have experienced intermittent reliability issues where replacement of nodes never finished or the cluster ended up in a unusable state. To avoid this, the process is applying the settings in a different manner.

On every node, a cron job is created which starts every 5 minutes. It runs a script that checks if any of the cluster-wide settings must be (re-)applied, then updates the local system and restarts the `crio` and `kubelet` daemons. If no settings are to be adjusted, the daemons will not be restarted and therefore the cron job has minimal or no effect on the running applications.

Compute node changes that are made by the cron job:
**ImageContentSourcePolicy**: File `/etc/containers/registries.conf` is updated to include registry mirrors for the private registry.
**Kubelet**: File `/etc/kubernetes/kubelet.conf` is appended with the `allowedUnsafeSysctls` entries.
**CRI-O**: `pids_limit` and `default_ulimit` changes are made to the `/etc/crio/crio.conf` file.
**Pull secret**: The registry and credentials are appended to the `/.docker/config.json` configuration.

There are scenarios, especially on IBM Cloud Satellite, where custom changes must be applied to the compute nodes. This is possible by adding the `apply-custom-node-settings.sh` to the `assets` directory within the `CONFIG_DIR` directory. Once Kubelet, CRI-O and other changes have been applied, this script (if existing) is run to apply any additional configuration changes to the compute node.

By setting the `NODE_UPDATED` script variable to `1` you can tell the deployer to restart the `crio` and `kubelet` daemons.

**WARNING:** You should never set the `NODE_UPDATED` script variable to `0` as this will cause previous changes to the pull secret, ImageContentSourcePolicy and others not to become effective.

Sample script:
```bash
#!/bin/bash

#
# This is a sample script that will cause the crio and kubelet daemons to be restarted once by checking
# file /tmp/apply-custom-node-settings-run. If the file doesn't exist, it creates it and sets NODE_UPDATED to 1.
# The deployer will observe that the node has been updated and restart the daemons.
#

if [ ! -e /tmp/apply-custom-node-settings-run ];then
    touch /tmp/apply-custom-node-settings-run
    NODE_UPDATED=1
fi

exit 0
```

### Mirror images to the private registry
If a private image registry is specified, and if the IBM Cloud Pak entitlement key is available in the vault (`cp_entitlement_key` secret), the Cloud Pak case files for the Foundational Services, the Cloud Pak control plane and cartridges are downloaded to a subdirectory of the status directory that was specified. Then all images defined for the cartridges are mirrored from the entitled registry to the private image registry. Dependent on network speed and how many cartridges have been configured, the mirroring can take a very long time (12+ hours). All images which have already been mirrored to the private registry are skipped by the mirroring process.

Even if all images have been mirrored, the act of checking existence and digest can still take a bit of time (10-15 minutes). To avoid this, you can remove the `cp_entitlement_key` secret from the vault and unset the `CP_ENTITLEMENT_KEY` environment variable before running the Cloud Pak Deployer.

### Create catalog sources
The images of the operators which control the Cloud Pak are defined in OpenShift `CatalogSource` objects which reside in the `openshift-marketplace` project. Operator subscriptions subsequently reference the catalog source and define the update channel. When images are pulled from the entitled registry, most subscriptions reference the same `ibm-operator-catalog` catalog source (and also a Db2U catalog source). If images are pulled from a private registry, the control plane and also each cartridge reference their own catalog source in the `openshift-marketplace` project.

This step creates the necessary catalog sources, dependent on whether the entitled registry or a private registry is used. For the entitled registry, it creates the catalog source directly using a YAML template; when using a private registry, the `cloudctl case` command is used for the control plane and every cartridge to install the catalog sources and their dependencies.

### Get OpenShift storage classes
Most custom resources defined by the cartridge operators require some back-end storage. To be able to reference the correct OpenShift storage classes, they are retrieved based on the `openshift_storage_name` property of the Cloud Pak object.

### Prepare the Cloud Pak for Data operator
When using express install, the Cloud Pak for Data operator also installs the Cloud Pak Foundational Services. Consecutively, this part of the deployer:

* Creates the operator project if it doesn't exist already
* Creates an OperatorGroup
* Installs the license service and certificate manager
* Creates the platform operator subscription
* Waits until the ClusterServerVersion objects for the platform operator and Operand Deployment Lifecycle Manager have been created

### Install the Cloud Pak for Data control plane
When the Cloud Pak for Data operator has been installed, the process continues by creating an OperandRequest object for the platform operator which manages the project in the which Cloud Pak for Data instance is installed. Then it creates an Ibmcpd custom resource in the project which installs the controle plane with nginx the metastore, etc.

The Cloud Pak for Data control plane is a pre-requisite for all cartridges so at this stage, the deployer waits until the Ibmcpd status reached the `Completed` state.

Once the control plane has been installed successfully, the deployer generates a new strong 25-character password for the Cloud Pak for Data `admin` user and stores this into the vault. Additionally, the `admin-user-details` secret in the OpenShift project is updated with the new password.

### Install the specified Cloud Pak for Data cartridges
Now that the control plane has been installed in the specified OpenShift project, cartridges can be installed. Every cartridge is controlled by its own operator subscription in the operators project and a custom resource. The deployer iterates twice over the specified cartridges, first to create the operator subscriptions, then to create the custom resources.

#### Create cartridge operator subscriptions
This steps creates `subscription` objects for each cartridge in the operators project, using a YAML template that is included in the deployer code and the `subscription_channel` specified in the cartridge definition. Keeping the subscription channel separate delivers flexibility when new subscription channels become available over time.

Once the subscription has been created, the deployer waits for the associate CSV(s) to be created and reach the `Installed` state.

#### Delete obsolete cartridges
If this is not the first installation, earlier configured cartridges may have been removed. This steps iterates over all supported cartridges and checks if the cartridge has been installed and wheter it exists in the configuration of the current `cp4d` object. If the cartridge is no longer defined, its custom resource is removed; the operator will then take care of removing all OpenShift configuration.

#### Install the cartridges
This steps creates the Custom Resources for each cartridge. This is the actual installation of the cartridge. Cartridges can be installed in parallel to a certain extent and the operator will wait for the dependencies to be installed first before starting the processes. For example, if Watson Studio and Watson Machine Learning are installed, both have a dependency on the Common Core Services (CCS) and will wait for the CCS object to reach the Completed state before proceeding with the install. Once that is the case, both WS and WML will run the installation process in parallel.

### Wait until all cartridges are ready
Installation of the cartridges can take a very long time; up to 5 hours for Watson Knowledge Catalog. While cartridges are being installed, the deployer checks the states of all cartridges on a regular basis and reports these in a log file. The deployer will retry until all specified cartridges have reached the `Completed` state.

### Configure LDAP authentication for Cloud Pak for Data
If LDAP has been configured for the Cloud Pak for Data element, it will be configured after all cartridges have finished installing.
