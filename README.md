# Cloud Pak Deployer

Cloud Pak Deployer simplifies both the initial installation and the ongoing
management of OpenShift and the Cloud Paks on top of it. The toolkit now
supports watsonx, Cloud Pak for Data & Software Hub, Cloud Pak for Integration,
Cloud Pak for Business Automation, and Cloud Pak for Watson AIOps across
infrastructures such as IBM Cloud ROKS, Azure Red Hat OpenShift (ARO), Red Hat
OpenShift on AWS (ROSA), VMWare vSphere and existing Red Hat OpenShift
environments.

To make the onboarding easier for every Cloud Pak profile, the repository ships
an interactive helper (`cp-deploy-helper/cpd_helper.py`). The helper collects
the IBM entitlement key, OpenShift access information, and the Cloud Pak
components you want to deploy, then generates a ready-to-run configuration and
environment script. You can still use raw YAML/GitOps workflows, but the helper
is the fastest way to build or update a configuration safely.

The Cloud Pak Deployer was created for a joint project with one of our key
partners who needed to fully automate the deployment of Cloud Pak for Data on
IBM Cloud based on a configuration kept in Git, and then make changes via
configuration updates (GitOps). The same approach now applies to the additional
Cloud Paks.

A couple of notes from the authors:
* If you find this repository useful, please **"Star"** it on GitHub to advertise it to a wider community
* If you have questions or problems, please open an issue in the GitHub repository
* Even better, if you find a defect and can resolve it, please fork the repository, fix it and send a pull request

> **DISCLAIMER** The scripts in this repository are provided **"as is"** and have been developed with several use cases in mind, from deploying canned demonstrations to proofs of concept, test deployments and production deployments. Their main goals are automation and acceleration of initial deployment, day 2 operations and continuous adoption of Cloud Pak updates. Scripts and playbooks in the Cloud Pak Deployer do not do anything "special" you could not do manually using the official documentation or via your own automation. IBM does not and cannot support the Cloud Pak Deployer; it is the responsibility of the installer to verify that the installation of Red Hat OpenShift and the Cloud Pak meets the requirements for resilience, security and other functional and non-functional aspects. You can choose to use the Cloud Pak Deployer in mission-critical environments such as production, but it is your responsibility to support such an installation.

**Thank you in advance for using this this toolkit!**
