# Using alternative repositories and registries

!!! warning
  In most scenarios you will not need this type of configuration. 

Alternative repositories and registries are mainly geared towards pre-GA use of the Cloud Paks where CASE files are downloaded from internal repositories and staging container image registries need to be used as images have not been released yet.

### Set path and alias for the deployer

``` { .bash .copy }
source ./set-env.sh
```

## Building the Cloud Pak Deployer image
By default the Cloud Pak Deployer image is built on top of the `olm-utils` images in `icr.io`. If you're working with a pre-release of the Cloud Pak OLM utils image, you can override the setting as follows:

``` { .bash .copy }
export CPD_OLM_UTILS_V2_IMAGE=cp.staging.acme.com:4.8.0
```

Or, for Cloud Pak for Data 5.0:
``` { .bash .copy }
export CPD_OLM_UTILS_V3_IMAGE=cp.staging.acme.com:5.0.0
```

Subsequently, run the install commmand:
``` { .bash .copy }
cp-deploy.sh build
```

## Configuring the alternative repositories and registries
When specifying a `cp_alt_repo` object in a YAML file, this is used for all Cloud Paks. The object triggers the following steps:
* The following files are created in the `/tmp/work` directory in the container: `play_env.sh`, `resolvers.yaml` and `resolvers_auth`.
* When downloading CASE files using the `ibm-pak` plug-in, the `play_env` sets the locations of the resolvers and authorization files.
* Also, the locations of the case files for the Cloud Pak, Foundational Servides and Open Content are set in an enviroment variable.
* Registry mirrors are configured using an `ImageContentSourcePolicy` resource in the OpenShift cluster.
* Registry credentials are added to the OpenShift cluster's global pull secret.

The `cp_alt_repo` is configured like this:
``` { .yaml .copy }
cp_alt_repo:
  repo:
    token_secret: github-internal-repo
    helm_path: https://raw.github.ibm.com/IBMSoftwareHub/charts/5.2.0/local
    cp_path: https://raw.github.ibm.com/PrivateCloud-analytics/cpd-case-repo/5.2.0/promoted/case-repo-promoted
    fs_path: https://raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case
    opencontent_path: https://raw.github.ibm.com/IBMPrivateCloud/cloud-pak/master/repo/case
  registry_pull_secrets:
  - registry: cp.staging.acme.com
    pull_secret: cp-staging
  - registry: fs.staging.acme.com
    pull_secret: cp-fs-staging
  registry_mirrors:
  - source: cp.icr.com/cp
    mirrors:
    - cp.staging.acme.com/cp
  - source: cp.icr.io/cp/cpd
    mirrors:
    - cp.staging.acme.com/cp/cpd
  - source: icr.io/cpopen
    mirrors:
    - fs.staging.acme.com/cp
  - source: icr.io/cpopen/cpfs
    mirrors:
    - fs.staging.acme.com/cp
```

## Property explanation
| Property       | Description                                                                            | Mandatory | Allowed values |
| -------------- | -------------------------------------------------------------------------------------- | --------- | -------------- |
| repo           | Repositories to be accessed and the Git token                                          | Yes       |                |
| repo.token_secret | Secret in the vault that holds the Git login token                                  | Yes       |                |
| repo.helm_path | Repository path where to find Software Hub helm files (required as from Software Hub 5.2.0) | No        |                |
| repo.cp_path   | Repository path where to find Cloud Pak CASE files                                     | Yes       |                |
| repo.fs)path   | Repository path where to find the Foundational Services CASE files                     | Yes       |                |
| repo.opencontent_path | Repository path where to find the Open Content CASE files                       | Yes       |                |
| registry_pull_secrets | List of registries and their pull secrets, will be used to configure global pull secret | Yes |              |
| .registry      | Registry host name                                                                     | Yes       |                |
| .pull_secret   | Vault secret that holds the pull secret (user:password) for the registry               | Yes       |                |
| registry_mirrors | List of registries and their mirrors, will be used to configure the ImageContentSourcePolicy | Yes |              |
| .source        | Registry and path referenced by the Cloud Pak/FS pod                                   | Yes       |                |
| .mirrors:      | List of alternate registry locations for this source                                   | Yes       |                |

## Configuring the secrets
Before running the deployer with a `cp_alt_repo` object, you need to ensure the referenced secrets are present in the vault.

For the GitHub token, you need to set the token (typically a deploy key) to login to GitHub or GitHub Enterprise.
``` { .bash .copy }
cp-deploy.sh vault set -vs github-internal-repo=abc123def456
```

For the registry credentials, specify the user and password separated by a colon (`:`):
``` { .bash .copy }
cp-deploy.sh vault set -vs cp-staging="cp-staging-user:cp-staging-password"
```

You can also set these tokens on the `cp-deploy.sh env apply` command line.
``` { .bash .copy }
cp-deploy.sh env apply -f -vs github-internal-repo=abc123def456 -vs cp-staging="cp-staging-user:cp-staging-password
```

## Running the deployer
To run the deployer you can now use the standard process:
``` { .bash .copy }
cp-deploy.sh env apply -v
```