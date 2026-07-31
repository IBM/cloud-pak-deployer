# Deployment topologies

Configuration of the topology to be deployed typically boils down to choosing the cloud infrastructure you want to deploy, then choosing the type of OpenShift and storage, integrating with infrastructure services and then setting up the Cloud Pak(s). For most initial implementations, a basic deployment will suffice and later this can be extended with additional configuration.

Depicted below is the basic deployment topology, followed by a topology with all bells and whistles.

## Basic deployment
![Basic deployment](images/cloud-pak-context-deployment-basic.png)

For more details on each of the configuration elements, refer to:

* [Infrastructure](infrastructure.md)
* [OpenShift](openshift.md)
* [Cloud Pak](cloud-pak.md)
* [Cloud Pak Cartridges](cp4d-cartridges.md)
* [Cloud Pak Instances](cp4d-instances.md)
* [Cloud Pak Assets](cp4d-assets.md)

## Extended deployment
![Extended deployment](images/cloud-pak-context-deployment-full.png)

For more details about extended deployment, refer to:

* [Monitoring](monitoring.md)
* [Logging and auditing](logging-auditing.md)
* [Private registry](private-registry.md)
* [DNS Servers](dns.md)
* [Cloud Pak for Data access control](cp4d-access-control.md)
* [Cloud Pak for Data SAML](cp4d-saml.md)