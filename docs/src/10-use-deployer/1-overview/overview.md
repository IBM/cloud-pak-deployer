# Using Cloud Pak Deployer

## Running Cloud Pak Deployer
There are 3 main steps you need to perform to provision an OpenShift cluster with the desired Cloud Pak(s):

1. [Install the Cloud Pak Deployer](../../../05-install/install)
2. [Configure the environment you want to deploy](../../../10-use-deployer/2-configure/configure)
3. [Run the Cloud Pak Deployer to create the cluster and install the Cloud Pak](../../../10-use-deployer/3-run/run)

## What will I need?
To complete the deployment, you will need the following. Details will be provided when you need them.

* Cloud Pak Entitlement Key: This key is essential for pulling images from the IBM Container Registry.
* IBM Cloud VPC: You will need an IBM Cloud API key to enable infrastructure provisioning.
* vSphere: Ensure you have the necessary vSphere user credentials, including a username and password, with permissions to create infrastructure.
* AWS ROSA: For AWS Red Hat OpenShift Service (ROSA), you should have AWS IAM credentials, including an access key and secret access key Additionally, you'll need a ROSA login token and, if necessary, a temporary security token.
* AWS Self-managed: If you are using AWS for self-managed OpenShift, you'll require AWS IAM credentials, including an access key and secret access key. Optionally, you may need a temporary security token.
* Azure ARO: For Azure Red Hat OpenShift (ARO), ensure you have your Azure subscription details and appropriate credentials on hand.
* Existing OpenShift: If you are working with an existing OpenShift cluster, be prepared with the cluster admin login credentials.

## Other "deployment" activities
There are a few activities that are somewhat related to deployment of the OpenShift cluster and/or Cloud Paks. These can also be performed through the deployer.

### Post-run configuration and secret retrieval

### Executing commands on the OpenShift cluster
The server on which you run the Cloud Pak Deployer may not have the necessary clients to interact with the cloud infrastructure, OpenShift, or the installed Cloud Pak. You can run commands using the same container image that runs the deployment of OpenShift and the Cloud Paks through the command line: [Open a command line](7-command/command)

### Destroying your OpenShift cluster
If you want to destroy the provisioned OpenShift cluster, including the installed Cloud Pak(s), you can do this through the Cloud pak Deployer. Steps can be found here: [Destroy the assets](../9-destroy/destroy)
