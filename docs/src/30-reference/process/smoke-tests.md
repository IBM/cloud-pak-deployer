---
title: Smoke tests
tabs: ['Overview', 'Validate', 'Prepare', 'Provision-infra', 'Configure-infra', 'Install-cloud-pak', 'Configure-cloud-pak', 'Deploy-assets', 'Smoke-tests']
---

# Smoke tests
This is the final stage before returning control to the process that started the deployer. Here tests to check that the Cloud Pak and its cartridges has been deployed correctly and that everything is running as expected.

The method for smoke tests should be dynamic, for example by referencing a Git repository and context (directory within the repository); the code within that directory then deploys the asset(s).

## Cloud Pak for Data smoke tests

### Show the Cloud Pak for Data URL and admin password
This "smoke test" finds the route of the Cloud Pak for Data instance(s) and retrieves the `admin` password from the vault which is then displayed.

Example:
```output
['CP4D URL: https://cpd-cpd.fke09-10-a939e0e6a37f1ce85dbfddbb7ab97418-0000.eu-gb.containers.appdomain.cloud', 'CP4D admin password: ITnotgXcMTcGliiPvVLwApmsV']
```

With this information you can go to the Cloud Pak for Data URL and login using the `admin` user.