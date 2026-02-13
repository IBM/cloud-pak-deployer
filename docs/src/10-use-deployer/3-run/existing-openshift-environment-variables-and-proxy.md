# Setting environment variables for the deployer

Some environments may have a need for special settings when running the deployer. Many of these such as the use of a proxy server for external communications can be configured using environment variables. You can create configuration map (ConfigMap) `cloud-pak-deployer-env` to set environment variables for the deployer jobs.


## Create the environment ConfigMap for external connections via a proxy server

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Update the environment variables and/or add new ones
???+ note "Set proxy variables"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cloud-pak-deployer-env
      namespace: cloud-pak-deployer
    data:
      http_proxy: http://192.168.217.111:31288
      https_proxy: http://192.168.217.111:3128
      no_proxy: kubernetes.default,.default,.cluster.local,.example.com,.svc,10.0.0.0/16,10.0.0.0/8,10.128.0.0/16,127.0.0.1,172.16.0.0/12,172.18.10.0/27,172.30.0.0/16,192.168.0.0/16,api-int.cpd.example.com,localhost
    ```

!!! warning
    Please ensure that you specify the correct proxy server and also include the servers that must not be connected via the proxy server. The OpenShift-internal host names such as `kubernetes.default` and IP addresses such as `172.30.0.0/16` must always be configured in `no_proxy`, otherwise the installation of services will not work.

## Create environment variable to run deployer with dry-run

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Update the environment variables and/or add new ones
???+ note "Run deployer with dry-run"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cloud-pak-deployer-env
      namespace: cloud-pak-deployer
    data:
      CPD_DRY_RUN: true
    ```

For a full list of environment variables, open the debug pod and run `/cloud-pak-deployer/cp-deploy.sh --help`.

## Create environment variable to set log level for the deployer wizard

* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Update the environment variables and/or add new ones
???+ note "Set log level for deployer wizard"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cloud-pak-deployer-env
      namespace: cloud-pak-deployer
    data:
      CPD_WIZARD_LOG_LEVEL: DEBUG
    ```

For a full list of environment variables, open the debug pod and run `/cloud-pak-deployer/cp-deploy.sh --help`.