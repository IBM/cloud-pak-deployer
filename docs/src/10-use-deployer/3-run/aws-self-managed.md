# Running the Cloud Pak Deployer on AWS (Self-managed)

On Amazon Web Services (AWS), OpenShift can be set up in various ways, managed by Red Hat (ROSA) or self-managed. The steps below are applicable to a self-managed OpenShift installation. The IPI (Installer Provisioned Infrastructure) installer will be used. More information about IPI installation can be found here: https://docs.openshift.com/container-platform/4.10/installing/installing_aws/installing-aws-customizations.html.

See the deployer in action in this video: https://ibm.box.com/v/cpd-aws-self-managed

## Topology

A typical setup of the self-managed OpenShift cluster is pictured below:
![AWS self-managed OpenShift](images/aws-self-managed-ocs.png)

## Single-node OpenShift (SNO) on AWS
Red Hat OpenShift also supports single-node deployments in which control plane and compute are combined into a single node. Obviously, this type of configuration does not cater for any high availability requirements that are usually part of a production installation, but it does offer a more cost-efficient option for development and testing purposes.

Cloud Pak Deployer can deploy a single-node OpenShift with elastic storage and a sample configuration is provided as part of the deployer.

!!! warning
    When deploying the IBM Cloud Paks on single-node OpenShift, there may be intermittent timeouts as pods are starting up. In those cases, just re-run the deployer with the same configuration and check status of the pods.

## Configure Route53 service on AWS

When deploying a self-managed OpenShift on Amazon web Services, a public hosted zone must be created in the same account as your OpenShift cluster. The domain name or subdomain name registered in the Route53 service must be specifed in the `openshift` configuration of the deployer. 

For more information on acquiring or specifying a domain on AWS, you can refer to https://github.com/openshift/installer/blob/master/docs/user/aws/route53.md.

## Obtain the AWS IAM credentials

If you can use your permanent security credentials for the AWS account, you will need an **Access Key ID** and **Secret Access Key** for the deployer to setup an OpenShift cluster on AWS. 

- Go to https://aws.amazon.com/
- Login to the AWS console
- Click on your user name at the top right of the screen
- Select **Security credentials**. You can also reach this screen via https://console.aws.amazon.com/iam/home?region=us-east-2#/security_credentials.
- If you do not yet have an access key (or you no longer have the associated secret), create an access key
- Store your **Access Key ID** and **Secret Access Key** in safe place

## Alternative: Using temporary AWS security credentials

If your account uses temporary security credentials for AWS resources, you must use the **Access Key ID**, **Secret Access Key** and **Session Token** associated with your temporary credentials. 

For more information about using temporary security credentials, see https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html.

The temporary credentials must be issued for an IAM role that has sufficient permissions to provision the infrastructure and all other components. More information about required permissions can be found here: https://docs.openshift.com/container-platform/4.10/authentication/managing_cloud_provider_credentials/cco-mode-sts.html#sts-mode-create-aws-resources-ccoctl.

An example on how to retrieve the temporary credentials for a user-defined role:
```
printf "\nexport AWS_ACCESS_KEY_ID=%s\nexport AWS_SECRET_ACCESS_KEY=%s\nexport AWS_SESSION_TOKEN=%s\n" $(aws sts assume-role \
--role-arn arn:aws:iam::678256850452:role/ocp-sts-role \
--role-session-name OCPInstall \
--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
--output text)
```

Thie would return something like the below, which you can then paste into the session running the deployer.
```output
export AWS_ACCESS_KEY_ID=ASIxxxxxxAW
export AWS_SECRET_ACCESS_KEY=jtLxxxxxxxxxxxxxxxGQ
export AWS_SESSION_TOKEN=IQxxxxxxxxxxxxxbfQ
```

If the `openshift` configuration has the `infrastructure.credentials_mode` set to `Manual`, Cloud Pak Deployer will automatically configure and run the Cloud Credential Operator utility.

## Acquire an OpenShift pull secret

To install OpenShift you need an OpenShift pull secret which holds your entitlement.

- Navigate to https://console.redhat.com/openshift/install/pull-secret and download the pull secret into file `/tmp/ocp_pullsecret.json`

## Acquire an IBM Cloud Pak Entitlement Key

If you want to pull the Cloud Pak images from the entitled registry (i.e. an online install), or if you want to mirror the images to your private registry, you need to download the entitlement key. You can skip this step if you're installing from a private registry and all Cloud Pak images have already been downloaded to the private registry.

- Navigate to https://myibm.ibm.com/products-services/containerlibrary and login with your IBMId credentials
- Select **Get Entitlement Key** and create a new key (or copy your existing key)
- Copy the key value

!!! warning
    As stated for the API key, you can choose to download the entitlement key to a file. However, when we reference the entitlement key, we mean the 80+ character string that is displayed, not the file.

## Optional: Locate or generate a public SSH Key
To obtain access to the OpenShift nodes post-installation, you will need to specify the public SSH key of your server; typically this is `~/.ssh/id_rsa.pub`, where `~` is the home directory of your user. If you don't have an SSH key-pair yet, you can generate one using the steps documented here: https://docs.openshift.com/container-platform/4.10/installing/installing_aws/installing-aws-customizations.html#ssh-agent-using_installing-aws-customizations. Alternatively, deployer can generate SSH key-pair automatically if credential `ocp-ssh-pub-key` is not in the vault.

## Prepare for running

### Set environment variables for AWS self-managed OpenShift cluster

```
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
export CP_ENTITLEMENT_KEY=your_cp_entitlement_key
```

Optional: If you want to use the temporary security credentials, you must set the `AWS_SESSION_TOKEN` to be used for the AWS CLI.
```
export AWS_SESSION_TOKEN=your_session_token
```

- `AWS_ACCESS_KEY_ID`: This is the AWS Access Key you retrieved above, often this is something like `AK1A2VLMPQWBJJQGD6GV`
- `AWS_SECRET_ACCESS_KEY`: The secret associated with your AWS Access Key, also retrieved above
- `AWS_SESSION_TOKEN`: The session token that will grant temporary elevated permissions
- `CP_ENTITLEMENT_KEY`: This is the entitlement key you acquired as per the instructions above, this is a 80+ character string

!!! warning
    If your `AWS_SESSION_TOKEN` is expires while the deployer is still running, the deployer may end abnormally. In such case, you can just issue new temporary credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN`) and restart the deployer. Alternatively, you can update the 3 vault secrets, respectively `aws-access-key`, `aws-secret-access-key` and `aws-session-token` with new values as they are re-retrieved by the deployer on a regular basis.

### Set deployer status directory
Cloud Pak Deployer uses the status directory to log its activities and also to keep track of its running state. For a given environment you're provisioning or destroying, you should always specify the same status directory to avoid contention between different deploy runs. 

```
export STATUS_DIR=$HOME/cpd-status
```

- `STATUS_DIR`: The directory where the Cloud Pak Deployer keeps all status information and logs files. **Please note** that if you have chosen to use a File Vault, the properties file is keps under the `vault` directory within the status directory. If you don't specify a status directory, it is assumted to be `$HOME/cpd-status`.

### Set deployer configuration location
You can use a local directory to hold the deployer configuration or retrieve the configuration from a GitHub repository. If you don't specify any configuration directory or GitHub repository, the configuration directory are assumed to be `$HOME/cpd-config`.
```
export CONFIG_DIR=$HOME/cpd-config
```

- `CONFIG_DIR`: Directory that holds the configuration, it must have a `config` subdirectory.

Or, when using a GitHub repository for the configuration.
```
export CPD_CONFIG_GIT_REPO="https://github.com/IBM/cloud-pak-deployer-config.git"
export CPD_CONFIG_GIT_REF="main"
export CPD_CONFIG_GIT_CONTEXT=""
```

- `CPD_CONFIG_GIT_REPO`: The clone URL of the GitHub repository that holds the configuration.
- `CPD_CONFIG_GIT_REF`: The branch, tag or commit ID to be cloned. If not specified, the repository's default branch will be cloned.
- `CPD_CONFIG_GIT_CONTEXT`: The directory within the GitHub repository that holds the configuration. This directory must contain the `config` directory under which the YAML files are kept.

!!! info
    When specifying a GitHub repository, the contents will be copied under `$STATUS_DIR/cpd-config` and this directory is then set as the configuration directory.    

### Create the secrets needed for self-managed OpenShift cluster

You need to store the below credentials in the vault so that the deployer has access to them when installing self-managed OpenShift cluster on AWS.

```
./cp-deploy.sh vault set \
    --vault-secret ocp-pullsecret \
    --vault-secret-file /tmp/ocp_pullsecret.json

# Optional if you would like to use your own public key
./cp-deploy.sh vault set \
    --vault-secret ocp-ssh-pub-key \
    --vault-secret-file ~/.ssh/id_rsa.pub
```

## Optional: validate the configuration

If you only want to validate the configuration, you can run the dpeloyer with the `--check-only` argument. This will run the first stage to validate variables and vault secrets and then execute the generators.

```
./cp-deploy.sh env apply --check-only [--accept-all-licenses]
```

## Run the Cloud Pak Deployer

To run the container using a local configuration input directory and a data directory where temporary and state is kept, use the example below. If you don't specify the status directory, the deployer will automatically create a temporary directory. Please note that the status directory will also hold secrets if you have configured a flat file vault. If you lose the directory, you will not be able to make changes to the configuration and adjust the deployment. It is best to specify a permanent directory that you can reuse later. If you specify an existing directory the current user **must** be the owner of the directory. Failing to do so may cause the container to fail with insufficient permissions.

```
./cp-deploy.sh env apply [--accept-all-licenses]
```

You can also specify extra variables such as `env_id` to override the names of the objects referenced in the `.yaml` configuration files as `{{ env_id }}-xxxx`. For more information about the extra (dynamic) variables, see [advanced configuration](../../../50-advanced/advanced-configuration).

The `--accept-all-licenses` flag is optional and confirms that you accept all licenses of the installed cartridges and instances. Licenses must be either accepted in the configuration files or at the command line.

When running the command, the container will start as a daemon and the command will tail-follow the logs. You can press Ctrl-C at any time to interrupt the logging but the container will continue to run in the background.

You can return to view the logs as follows:

```
./cp-deploy.sh env logs
```

Deploying the infrastructure, preparing OpenShift and installing the Cloud Pak will take a long time, typically between 1-5 hours,dependent on which Cloud Pak cartridges you configured. For estimated duration of the steps, refer to [Timings](../../../30-reference/timings).

If you need to interrupt the automation, use CTRL-C to stop the logging output and then use:

```
./cp-deploy.sh env kill
```

## On failure

If the Cloud Pak Deployer fails, for example because certain infrastructure components are temporarily not available, fix the cause if needed and then just re-run it with the same `CONFIG_DIR` and `STATUS_DIR` as well extra variables. The provisioning process has been designed to be idempotent and it will not redo actions that have already completed successfully.

## Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. You can also find this information under the `cloud-paks` directory in the status directory you specified.

To retrieve the Cloud Pak URL(s):

```
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd (domain name specified was example.com):
https://cpd-cpd.apps.pluto-01.example.com
```

The `admin` password can be retrieved from the vault as follows:

List the secrets in the vault:

```
./cp-deploy.sh vault list
```

This will show something similar to the following:

```output
Secret list for group sample:
- aws-access-key
- aws-secret-access-key
- ocp-pullsecret
- ocp-ssh-pub-key
- ibm_cp_entitlement_key
- pluto-01-cluster-admin-password
- cp4d_admin_zen_40_pluto_01
- all-config
```

You can then retrieve the Cloud Pak for Data admin password like this:

```
./cp-deploy.sh vault get --vault-secret cp4d_admin_zen_40_pluto_01
```

```output
PLAY [Secrets] *****************************************************************
included: /cloud-pak-deployer/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_40_pluto_01: gelGKrcgaLatBsnAdMEbmLwGr
```

## Post-install configuration
You can find examples of a couple of typical changes you may want to do here: [Post-run changes](../../../10-use-deployer/5-post-run/post-run).