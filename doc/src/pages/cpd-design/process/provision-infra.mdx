---
title: Provision infrastructure
tabs: ['Overview', 'Validate', 'Prepare', 'Provision-infra', 'Configure-infra', 'Install-cloud-pak', 'Configure-cloud-pak', 'Deploy-assets', 'Smoke-tests']
---

# Provision infrastructure

This stage will provision the infrastructure that was defined in the input configuration files. Currently, this has only been implemented for IBM Cloud.

## IBM Cloud
The IBM Cloud infrastructure provisioning runs Terraform to initially provision the infrastructure components such as VPC, VSIs, security groups, ROKS cluster and others. Also, if changes have been made in the configuration, Terraform will attempt to make the changes to reach the desired end-state.

Based on the chosen action (apply or destroy), Terraform is instructed to provision or change the infrastructure components or to destroy everything.

The Terraform state file (tfstate) is maintained in the vault and is critical to enable dynamic updates to the infrastructure. If the state file is lost or corrupted, updates to the infrastructure will have to be done manually. The Ansible tasks have been built in a way that the Terraform state file is always persisted into the vault, even if the apply or destroy process has failed.

There are 3 main steps:

#### Terraform init
This step initializes the Terraform provider (ibm) with the correct version. If needed, the Terraform modules for the provider are downloaded or updated.

#### Terraform plan
Applying changes to the infrastructure using Terraform based on the input configuration files may cause critical components to be replaced (destroyed and recreated). The plan step checks **what** will be changed. If infrastructure components are destroyed and the `--confirm-destroy` parameter has not be specified for the deployer, the process is aborted.

#### Terraform apply or Terraform destroy
This is the execution of the plan and will provision new infrastructure (apply) or destroy everything (destroy).

While the Terraform apply or destroy process is running, a `.tfstate` file is updated on disk. When the command completes, the deployer writes this as a secret to the vault so it can be used next time to update (or destroy) the infrastructure components.
