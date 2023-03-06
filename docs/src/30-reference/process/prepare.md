---
title: Prepare deployment
tabs: ['Overview', 'Validate', 'Prepare', 'Provision-infra', 'Configure-infra', 'Install-cloud-pak', 'Configure-cloud-pak', 'Deploy-assets', 'Smoke-tests']
---

# Prepare the deployer

This stage mainly takes care of checking the configuration and expanding it where necessary so it can be used by subsequent stages. Additionally, the preparation also calls the roles that will generate Terraform or other configuration files which are needed for provisioning and configuration.

## Generator
All `yaml` files in the `config` directory of the specified `CONFIG_DIR` are processed and a composite JSON object, `all_config` is created, which contains all configuration.

While processing the objects defined in the `config` directory files, the `defaults` directory is also processed to determine if any supplemental "default" variables must be added to the configuration objets. This makes it easy for example to ensure VSIs always use the correct Red Hat Enterprise Linux image available on IBM Cloud.

You will find the generator roles under the `automation-generators` directory. There are cloud-provider dependent roles such as `openshift` which have a structure dependent on the chosen cloud provider and there are generic roles such as `cp4d` which are not dependent on the cloud provider.

To find the appropriate role for the object, the generator first checks if the role is found under the specified cloud provider directory. If not found, it will call the role under `generic`.

### Linting
Each of the objects have a syntax checking module called `preprocessor.py`. This Python program checks the attributes of the object in question and can also add defaults for properties which are missing. All errors found are collected and displayed at the end of the generator.