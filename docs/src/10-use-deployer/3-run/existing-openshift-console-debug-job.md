## Start the deployer debug job only
* Go to the OpenShift console
* Click the "+" sign at the top of the page
* Paste the following block into the window. You can update the image on line 11 and the same value will be used for image for the Deployer Job (From release v3.0.2 onwards).

???+ note "Start the deployer debug job"
    ``` { .yaml .copy linenums="1" hl_lines="11" }
    {% include '../../../../scripts/deployer/assets/cloud-pak-deployer-start-debug.yaml' %}
    ```