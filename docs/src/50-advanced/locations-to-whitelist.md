---
title: Locations to whitelist on bastion
---
# Locations to whitelist on bastion

When building or running the deployer in an environment with strict policies for internet access, you may have to specify the list of URLs that need to be accessed by the deployer.

## Locations to whitelist when building the deployer image.
| Location                   | Used for                                   |
| -------------------------- | ------------------------------------------ |
| registry.access.redhat.com | Base image                                 |
| icr.io                     | olm-utils base image                       |
| cdn.redhat.com             | Installing operating system packages       |
| cdn-ubi.redhat.com         | Installing operating system packages       |
| rpm.releases.hashicorp.com | Hashicorp Vault integration                |
| dl.fedoraproject.org       | Extra Packages for Enterprise Linux (EPEL) |
| mirrors.fedoraproject.org  | EPEL mirror site                           |
| fedora.mirrorservice.org   | EPEL mirror site                           |
| pypi.org                   | Python packages for deployer               |
| galaxy.ansible.com         | Ansible Galaxy packages                    |


## Locations to whitelist when running the deployer for existing OpenShift.
| Location                      | Used for                                                 |
| ----------------------------- | -------------------------------------------------------- |
| github.com                    | Case files, Cloud Pak clients: cloudctl, cpd-cli.        |
| gcr.io                        | Google Container Registry (GCR)                          |
| objects.githubusercontent.com | Binary content for github.com                            |
| raw.githubusercontent.com     | Binary content for github.com                            |
| mirror.openshift.com          | OpenShift client                                         |
| ocsp.digicert.com             | Certificate checking                                     |
| subscription.rhsm.redhat.com  | OpenShift subscriptions                                  |
