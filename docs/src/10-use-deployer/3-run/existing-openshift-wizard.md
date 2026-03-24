# Run deployer wizard on OpenShift

## Log in to the OpenShift cluster
Log is as a cluster administrator to be able to run the deployer with the correct permissions.

## Prepare the deployer project
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block (exactly) into the window
???+ note "Prepare the deployer project"
    ``` { .yaml .copy }
{% include '../../../../scripts/deployer/assets/cloud-pak-deployer-project.yaml' %}
    ```
    
## Start the deployer
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job

!!! info
    The below starts the deployer wizard using the standard configuration. Additionally, you can:
    
    * Configure environment variables such as proxy server or the wizard logging level. See [Configure environment variables for proxy and other settings](./existing-openshift-environment-variables-and-proxy.md){target="_blank}

???+ note "Start the deployer wizard"
    ``` { .yaml .copy linenums="1" hl_lines="11" }
    {% include '../../../../scripts/deployer/assets/cloud-pak-deployer-start-wizard.yaml' %}
    ```

## Open the wizard

Once the start pod finishes, you can access the deployer wizard using the route created in the `cloud-pak-deployer` project.

!!! info 
    It may take a few minutes (5-10 minutes) until the route is created by the `deployer-start` pod and then an additional few minutes before the wizard has been started. If you don't see the route immediately, or if the deployer wizard page does not show up, please be patient.

* Open the OpenShift console
* Go to Networking --> Routes
* Click the Cloud Pak Deployer `wizard` route
* Log in using your OpenShift cluster admin credentials (typically `kubeadmin`)
* Accept the information that will be shared with Cloud Pak Deployer