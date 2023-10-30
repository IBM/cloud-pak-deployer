# Uninstall Cloud Pak for Data and Foundational Services

For convenience, the Cloud Pak Deployer includes a script that removes the Cloud Pak for Data instance from the OpenShift cluster, then Cloud Pak Foundational Services and finally the catalog sources and CRDs.

Steps:

* Make sure you are connected to the OpenShift cluster
* Run script `./scripts/cp4d/cp4d-delete-instance.sh <CP4D_project>`

You will have to confirm that you want to delete the instance and all other artifacts.

!!! Warning
    Please be very careful with this command. Ensure you are connected to the correct OpenShift cluster and that no other Cloud Paks use operator namespace. The action cannot be undone.