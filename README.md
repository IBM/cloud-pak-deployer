# Cloud Pak Deployer

The intention of the Cloud Pak Deployer is to simplify the initial installation and also continuous management of OpenShift and the Cloud Paks on top of that, driven by automation. It will help you deploy (currently) Cloud Pak for Data on various Red Hat OpenShift and infrastructures such as IBM Cloud ROKS, Azure Red Hat OpenShift (ARO), Red Hat OpenShift on AWS (ROSA), VMWare vSphere and also on existing Red Hat OpenShift environments.

The Cloud Pak Deployer was created for a joint project with one of our key partners who need to fully automate the deployment of Cloud Pak for Data on IBM Cloud based on a configuration that is kept in a Git repository, and make changes to it via configuration changes, i.e. GitOps.

A couple of notes from the authors:
* If you find this repository useful, please **"Star"** it on GitHub to advertise it to a wider community
* If you have questions or problems, please open an issue in the GitHub repository
* Even better, if you find a defect and can resolve it, please fork the repository, fix it and send a pull request

> **DISCLAIMER** The scripts in this repository are provided **"as is"** and have been developed with several use cases in mind, from deploying canned demonstrations to proofs of concept, test deployments and production deployments. Their main goals are automation and acceleration of initial deployment, day 2 operations and continuous adoption of Cloud Pak updates. Scripts and playbooks in the Cloud Pak Deployer do not do anything "special" you could not do manually using the official documentation or via your own automation. IBM does not and cannot support the Cloud Pak Deployer; it is the responsibility of the installer to verify that the installation of Red Hat OpenShift and the Cloud Pak meets the requirements for resilience, security and other functional and non-functional aspects. You can choose to use the Cloud Pak Deployer in mission-critical environments such as production, but it is your responsibility to support such an installation.

**Thank you in advance for using this this toolkit!**