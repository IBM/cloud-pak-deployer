# Deploy assets

## Deployer hooks
There are serveral points where you can make the deployer run Ansible tasks, for example to do additional configuration steps like LDAP provisioning and deploying assets. The names of the `.yml` that can be used as hooks inside the deployer process are fixed and must be placed inside the `$CONFIG_DIR/assets` directory.

![Overview of the deployer process](../process/images/provisioning-process.png)

Hooks:

* Pre-validation (phase 10): `deployer-hook-pre-10-validation.yml`
* Pre-prepare (phase 20): `deployer-hook-pre-20-prepare.yml`
* Pre-provision-infra (phase 30): `deployer-hook-pre-30-provision-infra.yml`
* Pre-configure-infra (phase 40): `deployer-hook-pre-40-configure-infra.yml`
* Pre-install-cloud-pak (phase 50): `deployer-hook-pre-50-install-cloud-pak.yml`
* Pre-configure-cloud-pak (phase 60): `deployer-hook-pre-60-configure-cloud-pak.yml`
* Pre-deploy-assets (phase 70): `deployer-hook-pre-70-deploy-assets.yml`
* Pre-deploy-assets (phase 80): `deployer-hook-pre-80-smoke-tests.yml`

The hooks are only called once per phase. It is the responsibility of the user to do any validation and error handling inside the Ansible tasks.

Sample hooks can be found in the `sample-configurations/sample-dynamic/config-samples/assets` directory in the deployer GitHub repository.

## Cloud Pak for Data
For Cloud Pak for Data, this stage does the following:

* Deploy Cloud Pak for Data assets which are defined with object `cp4d_asset`
* Deploy the Cloud Pak for Data monitors identified with `cp4d_monitors` elements.

### Deploy Cloud Pak for Data assets
See [cp4d_asset](../../../30-reference/configuration/cp4d-assets) for more details.

### Cloud Pak for Data monitors
See [cp4d_monitors](../../../30-reference/configuration/monitoring) for more details.