# Using Cloud Pak Deployer

## Running Cloud Pak Deployer
There are 3 main steps you need to perform to provision an OpenShift cluster with the desired Cloud Pak(s):

1. [Install the Cloud Pak Deployer](../../../05-install/install), when not running from OpenShift console
2. [Run the Cloud Pak Deployer to create the cluster and install the Cloud Pak](../../../10-use-deployer/3-run/run)

## What will I need?
To complete the deployment, you will or may need the following. Details will be provided when you need them.

* Your Cloud Pak entitlement key to pull images from the IBM Container Registry
* IBM Cloud VPC: An IBM Cloud API key that allows you to provision infrastructure
* vSphere: A vSphere user and password which has infrastructure create permissions
* AWS ROSA: AWS IAM credentials (access key and secret access key), a ROSA login token and optionally a temporary security token
* AWS Self-managed: AWS IAM credentials (access key and secret access key) and optionally a temporary security token
* Azure: Azure service principal with the correct permissions
* Existing OpenShift: Cluster admin login credentials of the OpenShift cluster

### Executing commands on the OpenShift cluster
The server on which you run the Cloud Pak Deployer may not have the necessary clients to interact with the cloud infrastructure, OpenShift, or the installed Cloud Pak. You can run commands using the same container image that runs the deployment of OpenShift and the Cloud Paks through the command line: [Open a command line](7-command/command)

### Destroying your OpenShift cluster
If you want to destroy the provisioned OpenShift cluster, including the installed Cloud Pak(s), you can do this through the Cloud pak Deployer. Steps can be found here: [Destroy the assets](../9-destroy/destroy)
