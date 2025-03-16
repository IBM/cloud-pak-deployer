# Cloud Pak for Data Asset configuration

The Cloud Pak Deployer can implement demo assets and accelerators as part of the deployment process to standardize standing up fully-featured demo environments, or to test patches or new versions of the Cloud Pak using pre-defined assets.

## Node changes for ROKS and Satellite clusters
If you put a script named `apply-custom-node-settings.sh` in the `CONFIG_DIR/assets` directory, it will be run as part of applying the node settings. This way you can override the existing node settings applied by the deployer or update the compute nodes with new settings. For more information regarding the `apply-custom-node-settings.sh` script, go to [Prepare OpenShift cluster on IBM Cloud and IBM Cloud Satellite](../process/install-cloud-pak.md#prepare-openshift-cluster-on-ibm-cloud-and-ibm-cloud-satellite).

## `cp4d_asset`
A `cp4d_asset` entry defines one or more assets to be deployed for a specific Cloud Pak for Data instance (OpenShift project). In the configuration, a directory relative to the configuration directory (`CONFIG_DIR`) is specified. For example, if the directory where the configuration is stored is `$HOME/cpd-config/sample` and you specify `assets` as the asset directory, all assets under `/cpd-config/sample/assets` are processed.

You can create one or more subdirectories under the specified location, each holding an asset to be deployed. The deployer finds all `cp4d-asset.sh` scripts and `cp4d-asset.yaml` Ansible task files and runs them.

The following runtime attributes will be set prior to running the shell script or the Ansible task:
* If the Cloud Pak for Data instances has the Common Core Services (CCS) custom resource installed, `cpdctl` is configured for the current Cloud Pak for Data instance and the current context is set to the `admin` user of the instance. This means you can run all `cpdctl` commands without first having to login to Cloud Pak for Data.
* The current working directory is set to the directory holding the `cp4d-asset.sh` script.
* When running the `cp4d-asset.sh` shell script, the following environment variables are available:
    - `CP4D_URL`: Cloud Pak for Data URL
    - `CP4D_ADMIN_PASSWORD`: Cloud Pak for Data admin password
    - `CP4D_OCP_PROJECT`: OpenShift project that holds the Cloud Pak for Data instance
    - `KUBECONFIG`: OpenShift configuration file that allows you to run `oc` commands for the cluster

```
cp4d_asset:
- name: sample-asset
  project: cpd
  asset_location: cp4d-assets
```

#### Property explanation
| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| name     | Name of the asset to be deployed. You can specify as many assets as wanted | Yes       |  |
| project  | Name of OpenShift project of the matching `cp4d` entry. The cp4d project must exist. | Yes       |  |
| asset_location | Directory holding the asset(s). This is a directory relative to the config directory (CONFIG_DIR) that was passed to the deployer | Yes |  |


#### Asset example
Below is an example asset that implements the **Customer Attrition** industry accelerator, which can be found here: https://github.com/IBM/Industry-Accelerators/blob/master/CPD%204.0.1.0/utilities-customer-attrition-prediction-industry-accelerator.tar.gz

To implement:

* Download the zip file to the `cp4d-assets` directory in the specified configuration directory
* Create the `cp4d-asset.sh` shell script (example below)
* Add a `cp4d_asset` entry to the Cloud Pak for Data config file in the `config` directory (or in any other file with extention `.yaml`)

`cp4d-asset.sh` shell script:
```
#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# Function to retrieve project by name
function retrieve_project {
    project_name=$1

    # First check if project already exists
    project_id=$(cpdctl project list \
        --output json | \
        jq -r --arg project_name $project_name \
        'if .total_results==0 then "" else .resources[] | select(.entity.name == $project_name) | .metadata.guid end')

    echo $project_id
}

# Function to create a project
function create_project {
    project_name=$1

    retrieve_project $project_name

    if [ "$project_id" != "" ];then
        echo "Project $project_name already exists"
        return
    else
        echo "Creating project $project_name"
        storage_id=$(uuidgen)
        storage=$(jq --arg storage_id $storage_id '. | .guid=$storage_id | .type="assetfiles"' <<< '{}')
        cpdctl project create --name $project_name --storage "$storage"
    fi

    # Find project_id to return
    project_id=$(cpdctl project list \
        --output json | \
        jq -r --arg project_name $project_name \
        'if .total_results==0 then "" else .resources[] | select(.entity.name == $project_name) | .metadata.guid end')
}

# Function to import a project
function import_project {
    project_id=$1
    zip_file=$2
    import_id=$(cpdctl asset import start \
        --project-id $project_id --import-file $zip_file \
        --output json --jmes-query "metadata.id" --raw-output)
    
    cpdctl asset import get --project-id $project_id --import-id $import_id --output json

}

# Function to run jobs
function run_jobs {
    project_id=$1
    for job in $(cpdctl job list --project-id $project_id \
        --output json | jq -r '.results[] | .metadata.asset_id');do
        cpdctl job run create --project-id $project_id --job-id $job --job-run "{}"
    done
}

#
# Start of the asset code
#

# Unpack the utilities-customer-attrition-prediction-industry-accelerator directory
rm -rf /tmp/utilities-customer-attrition-prediction-industry-accelerator
tar xzf utilities-customer-attrition-prediction-industry-accelerator.tar.gz -C /tmp
asset_dir=/tmp/customer-attrition-prediction-industry-accelerator

# Change to the asset directory
pushd ${asset_dir} > /dev/null

# Log on to Cloud Pak for Data with the admin user
cp4d_token=$(curl -s -k -H 'Content-Type: application/json' -X POST $CP4D_URL/icp4d-api/v1/authorize -d '{"username": "admin", "password": "'$CP4D_ADMIN_PASSWORD'"}' | jq -r .token)

# Import categories
curl -s -k -H 'accept: application/json' -H "Authorization: Bearer ${cp4d_token}" -H "content-type: multipart/form-data" -X POST $CP4D_URL/v3/governance_artifact_types/category/import?merge_option=all -F "file=@./utilities-customer-attrition-prediction-glossary-categories.csv;type=text/csv"

# Import glossary terms
curl -s -k -H 'accept: application/json' -H "Authorization: Bearer ${cp4d_token}" -H "content-type: multipart/form-data" -X POST $CP4D_URL/v3/governance_artifact_types/glossary_term/import?merge_option=all -F "file=@./utilities-customer-attrition-prediction-glossary-terms.csv;type=text/csv"

# Check if customer-attrition project already exists. If so, do nothing
project_id=$(retrieve_project "customer-attrition")

# If project does not exist, import it and run jobs
if [ "$project_id" == "" ];then
    create_project "customer-attrition"
    import_project $project_id \
        /tmp/utilities-customer-attrition-prediction-industry-accelerator/utilities-customer-attrition-prediction-analytics-project.zip
    run_jobs $project_id
else
    echo "Skipping deployment of CP4D asset, project customer-attrition already exists"
fi

# Return to original directory
popd > /dev/null

exit 0
```