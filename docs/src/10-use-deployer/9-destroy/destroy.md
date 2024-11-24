# Destroy the created resources

If you have previously used the Cloud Pak Deployer to create assets, you can destroy the assets with the same command.

!!! info
    Currently, destroy is only implemented for OpenShift clusters on IBM Cloud ROKS, AWS and Azure, and for Cloud Pak for Data on an existing OpenShift cluster.

## Prepare for destroy

### Prepare for destroy on existing OpenShift

#### Set environment variables for existing OpenShift

Optional: set environment variables for deployer config and status directories. If not specified, respectively `$HOME/cpd-config` and `$HOME/cpd-status` will be used.
``` { .bash .copy }
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and log files. **Please note** that if you have chosen to use a File Vault, the directory specified must be the one you used when you created the environment
- `CONFIG_DIR`: Directory that holds the configuration. This must be the same directory you used when you created the environment

### Prepare for destroy on IBM Cloud

#### Set environment variables for IBM Cloud

``` { .bash .copy }
export IBM_CLOUD_API_KEY=your_api_key
```

Optional: set environment variables for deployer config and status directories. If not specified, respectively `$HOME/cpd-config` and `$HOME/cpd-status` will be used.
``` { .bash .copy }
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `IBM_CLOUD_API_KEY`: This is the API key you generated using your IBM Cloud account, this is a 40+ character string
- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and log files. **Please note** that if you have chosen to use a File Vault, the directory specified must be the one you used when you created the environment
- `CONFIG_DIR`: Directory that holds the configuration. This must be the same directory you used when you created the environment

### Prepare for destroy on AWS

#### Set environment variables for AWS

We assume that the vault already holds the mandatory secrets for AWS Access Key, Secret Access Key and ROSA login token.

``` { .bash .copy }
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and log files. **Please note** that if you have chosen to use a File Vault, the directory specified must be the one you used when you created the environment
- `CONFIG_DIR`: Directory that holds the configuration. This must be the same directory you used when you created the environment

### Prepare for destroy on Azure

#### Set environment variables for Azure

We assume that the vault already holds the mandatory secrets for Azure - Service principal id and its password, tenant id and ARO login token.

``` { .bash .copy }
export STATUS_DIR=$HOME/cpd-status
export CONFIG_DIR=$HOME/cpd-config
```

- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and log files. **Please note** that if you have chosen to use a File Vault, the directory specified must be the one you used when you created the environment
- `CONFIG_DIR`: Directory that holds the configuration. This must be the same directory you used when you created the environment

## Run the Cloud Pak Deployer to destroy the assets

``` { .bash .copy }
./cp-deploy.sh env destroy --confirm-destroy
```

Please ensure you specify the same extra (dynamic) variables that you used when you ran the `env apply` command.

When running the command, the container will start as a daemon and the command will tail-follow the logs. You can press Ctrl-C at any time to interrupt the logging but the container will continue to run in the background.

You can return to view the logs as follows:

``` { .bash .copy }
./cp-deploy.sh env logs
```

If you need to interrupt the process, use CTRL-C to stop the logging output and then use:

``` { .bash .copy }
./cp-deploy.sh env kill
```

## Finishing up

Once the process has finished successfully, you can delete the status directory.
