# Running deployer on OpenShift using console

See the deployer in action deploying IBM watsonx.ai on an existing OpenShift cluster in this video:

<video src="https://ibm.box.com/shared/static/iabmg861w5eiz30pwh4ph2chlv2m1k6q.mp4" controls="controls" muted="muted" class="d-block rounded-bottom-2 border-top width-fit" style="max-height:300px; min-height: 200px"></video>

## Log in to the OpenShift cluster
Log in as a cluster administrator to be able to run the deployer with the correct permissions.

## TechZone clusters and Watson Studio Pipelines (Pipeline Orchestration)

!!! warning "OpenShift Pipelines must be removed manually"
    The Watson Studio Pipelines cartridge (also referred to as Pipeline Orchestration) installs its own Tekton controllers.  
    TechZone OpenShift clusters already include the Red Hat OpenShift Pipelines operator that owns the same Tekton
    resources, so the install fails if both are present. The Cloud Pak Deployer does **not** uninstall shared cluster
    components. Remove OpenShift Pipelines yourself **before** you add `ws-pipelines` to the configuration.

Follow these steps once per cluster:

1. Sign in to the OpenShift web console with a cluster-admin user.
2. Go to `Operators` → `Installed Operators`, open **OpenShift Pipelines** (namespace `openshift-operators`), choose **Actions → Uninstall**, keep *Delete operand resources* selected, and confirm.
3. Wait until the operator disappears from the list and the `openshift-pipelines-operator` CSV is removed.
4. Verify that no `TektonConfig` instance is left. The following command should return *No resources found*:
   ```bash
   oc get tektonconfig
   ```
5. If a `tekton-pipelines` project still exists, delete it to remove the remaining webhooks.

TechZone automation itself runs on OpenShift Pipelines, so uninstalling it stops the TechZone pipeline that would normally start the deployer. After completing the above steps, start the deployer directly from the OpenShift console (as described below). You can reinstall OpenShift Pipelines from OperatorHub again after Watson Studio Pipelines has been successfully deployed.

## Prepare the deployer project
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
???+ note "Prepare the deployer project"
    ``` { .yaml .copy }
{% include '../../../../scripts/deployer/assets/cloud-pak-deployer-project.yaml' %}
    ```

## Set the entitlement key
* Update the secret below with your container software Entitlement key from https://myibm.ibm.com/products-services/containerlibrary. Make sure the key is indented exactly as below.
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block with **replaced YOUR_ENTITLEMENT_KEY** on line 10
???+ note "Set the entitlement key"
    ``` { .yaml .copy linenums="1" hl_lines="10" }
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: cloud-pak-entitlement-key
      namespace: cloud-pak-deployer
    type: Opaque
    stringData:
      cp-entitlement-key: |
        YOUR_ENTITLEMENT_KEY
    ```

## Configure the Cloud Paks and services to be deployed
* Update the configuration below to match what you want to deploy, do not change indent
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the below block (exactly into the window)
* Update the `cp4d` element and select the version and cartridges you want to install

!!! info
    The below is an example of a Software Hub installation. Other example configurations:
    
    * [Software Hub with Keycloak as the identity provider](./existing-openshift-software-hub-keycloak.md){target="_blank}

    * [Cloud Pak for Integration](./existing-openshift-cp4i.md){target="_blank}


???+ note "Sample CP4D configuration"
    ``` { .yaml .copy }
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cloud-pak-deployer-config
      namespace: cloud-pak-deployer
    data:
      cpd-config.yaml: |
        {% include '../../../../sample-configurations/sample-dynamic/config-samples/ocp-existing-ocp-auto.yaml' %}
        
        {% include '../../../../sample-configurations/sample-dynamic/config-samples/cp4d-latest.yaml' %}
    ```

## Start the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job (From release v3.0.2 onwards).

!!! info
    The below starts the deployer apply process using the above configuration. Additionally, you can:
    
    * Start only the debug job and run the deployer in the debug pod. See [Start deployer debug job](./existing-openshift-console-debug-job.md){target="_blank}
    * Configure environment variables such as proxy server. See [Configure environment variables for proxy and other settings](./existing-openshift-environment-variables-and-proxy.md){target="_blank}

???+ note "Start the deployer"
    ``` { .yaml .copy linenums="1" hl_lines="11" }
    {% include '../../../../scripts/deployer/assets/cloud-pak-deployer-start.yaml' %}
    ```

## Follow the logs of the deployment
* Open the OpenShift console
* Go to Workloads --> Pods
* Select `cloud-pak-deployer` as the project at the top of the page
* Click the deployer Pod
* Click Logs tab

!!! info
    When running the deployer installing Cloud Pak for Data, the first run will fail. This is because the deployer applies the node configuration to OpenShift, which will cause all nodes to restart one by one, including the node that runs the deployer. Because of the Job setting, a new deployer pod will automatically start and resume from where it was stopped.  

## Finishing up

Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. 
```
--- Cloud Pak for Data project cpd ---
CP4D URL: https://cpd-cpd.apps.6759f8089266ae8f450d554f.ocp.techzone.ibm.com
CP4D User: cpadmin
CP4D cpadmin password: <your-cpadmin-password>
```

You can also find this information under the `cloud-paks` directory in the status directory you specified. The following commands can be run from the **debug** pod terminal that is in the `cloud-pak-deployer` project.

To retrieve the Cloud Pak URL(s):

``` { .bash .copy }
cat $STATUS_DIR/cloud-paks/*
```

This will show the Cloud Pak URLs:

```output
Cloud Pak for Data URL for cluster pluto-01 and project cpd (domain name specified was example.com):
https://cpd-cpd.apps.pluto-01.example.com
```

The `admin` password can be retrieved from the vault as follows:

List the secrets in the vault:

``` { .bash .copy }
cp-deploy.sh vault list
```

This will show something similar to the following:

```output
Secret list for group sample:
- ibm_cp_entitlement_key
- oc-login
- cp4d_admin_cpd_demo
```

You can then retrieve the Cloud Pak for Data admin password like this:

``` { .bash .copy }
cp-deploy.sh vault get --vault-secret cp4d_admin_cpd_sample
```

```output
PLAY [Secrets] *****************************************************************
included: /cloud-pak-deployer/automation-roles/99-generic/vault/vault-get-secret/tasks/get-secret-file.yml for localhost
cp4d_admin_zen_sample_sample: gelGKrcgaLatBsnAdMEbmLwGr
```


Once the process has finished, it will output the URLs by which you can access the deployed Cloud Pak. 
```
--- Cloud Pak for Data project cpd ---
CP4D URL: https://cpd-cpd.apps.6759f8089266ae8f450d554f.ocp.techzone.ibm.com
CP4D User: cpadmin
CP4D cpadmin password: <your-cpadmin-password>
```

## Re-run deployer when failed or if you want to update the configuration
If the deployer has failed or if you want to make changes to the configuration after the successful run, you can do the following:

* Open the OpenShift console
* Go to Workloads --> Jobs
* Check the logs of the `cloud-pak-deployer` job
* If needed, make changes to the `cloud-pak-deployer-config` Config Map by going to Workloads --> ConfigMaps
* [Re-run the deployer](#start-the-deployer)
