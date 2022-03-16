#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage: "
    echo ""
    echo "assign_datastage_authorization.sh"
    echo "  <CLOUD_PAK_FOR_DATA_URL>"
    echo "  <CLOUD_PAK_FOR_DATA_BEARER_TOKEN>"
    echo "  <CLOUD_PAK_FOR_DATA_DATASTAGE_INSTANCE_NAME>"    
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>"
    echo "  <CLOUD_PAK_FOR_DATA_DATASTAGE_ROLE>"
    echo ""
    echo "Example command:"
    echo "./assign_datastage_authorization.sh"
    echo "  https://......"
    echo "  <bearer token>"
    echo "  \"datastage-instance-1\""
    echo "  \"DS_Administrators\""
    echo "  \"Admin\""
    echo ""
    exit 0
fi

if [ "$#" -ne 5 ]; then
    echo "Incorrect number of parameters provided."
    echo "Run ./assign_datastage_authorization.sh for help command"
    exit 1
fi

export CP4D_URL=$1
export CP4D_BEARER_TOKEN=$2
export CP4D_DATASTAGE_INSTANCE_NAME=$3
export CP4D_ROLE_GROUP_NAME=$4
export CP4D_DATASTAGE_ROLE=$5

export CP4D_URL_GROUPS=${CP4D_URL}/usermgmt/v2/groups
export CP4D_INSTANCES=${CP4D_URL}/zen-data/v3/service_instances
export CP4D_INSTANCES_USERS=${CP4D_URL}/zen-data/v2/serviceInstance/users
export CP4D_INSTANCES_USERS_ROLE=${CP4D_INSTANCES_USERS}/role
export CP4D_INSTANCES_GROUPS=${CP4D_URL}/zen-data/v2/serviceInstance/groups

#Default list of DataStage Roles
export CP4D_DATASTAGE_ROLES=("Admin" "Operator")

echo ""
echo "==> Summarize task"
echo ""
echo "=================="
echo "IBM Cloud Pak for Data URL: ${CP4D_URL}"
echo "DataStage instance name:  ${CP4D_DATASTAGE_INSTANCE_NAME}"
echo "User Group Name: ${CP4D_ROLE_GROUP_NAME}" 
echo "DataStage role: ${CP4D_DATASTAGE_ROLE}"

echo ""
echo "==> 1. Validate the provided DataStage role \"${CP4D_DATASTAGE_ROLE}\" is available in DataStage for Cloud Pak for Data"
echo ""
echo "=================="
if [[ ! " ${CP4D_DATASTAGE_ROLES[@]} " =~ " ${CP4D_DATASTAGE_ROLE} " ]]; then
    echo "Provided Role \"${CP4D_DATASTAGE_ROLE}\" is not part of the available roles in DataStage for Cloud Pak for Data."
    echo "Only the following DataStage roles are available in Cloud Pak for Data:"
    for DATASTAGE_ROLE in "${CP4D_DATASTAGE_ROLES[@]}"
    do
        echo " - ${DATASTAGE_ROLE}"
    done    
    exit 1
fi

echo ""
echo "==> 2. Validate if User Group \"${CP4D_ROLE_GROUP_NAME}\" already exists"
echo ""
echo "=================="
export GROUP_SEARCH=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS})
export GROUP_ID=$(echo ${GROUP_SEARCH} | jq -r ".results[] | select(.name==\"${CP4D_ROLE_GROUP_NAME}\") | .group_id")

if [ -z "$GROUP_ID" ]
then
    echo "CP4D User Group \"${CP4D_ROLE_GROUP_NAME}\" does not exist. Ensure the User Group exists prior to running this script"
    exit 1
fi

echo ""
echo "==> 3. Acquire DataStage Instance ID"
echo ""
echo "=================="
export DATASTAGE_INSTANCE_ID=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_INSTANCES} | jq -r ".service_instances[] | select(.display_name==\"${CP4D_DATASTAGE_INSTANCE_NAME}\") | .id")

if [[ -z "$DATASTAGE_INSTANCE_ID" || "$DATASTAGE_INSTANCE_ID" == "null" ]]
then
    echo "Unable to fetch DataStage Instance ID. Ensure a DataStage instance with name \"${CP4D_DATASTAGE_INSTANCE_NAME}\" is provisioned and running..."
    exit 1
else
    echo "Cloud Pak for Data DataStage instance \"${CP4D_DATASTAGE_INSTANCE_NAME}\" ID: ${DATASTAGE_INSTANCE_ID}"
fi

echo ""
echo "==> 4. Get current group assignment to instance"
echo ""
echo "=================="
export CURRENT_GROUP_ASSIGNMENTS=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_GROUPS}?sID=${DATASTAGE_INSTANCE_ID})

export CP4D_DATASTAGE_GROUP_ASSIGNMENT=$(jq -r ".data[] | select(.GroupName==\"${CP4D_ROLE_GROUP_NAME}\") | .GroupName" <<< ${CURRENT_GROUP_ASSIGNMENTS})

if [ -z "${CP4D_DATASTAGE_GROUP_ASSIGNMENT}" ]
then
    echo "Cloud Pak for Data Group \"${CP4D_ROLE_GROUP_NAME}\" not yet assigned to DataStage instance, assigning group..."

    export ADD_GROUP_TO_DATASTAGE=$(curl -s -k -X POST -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS} \
        -d "{\"serviceInstanceID\":\"${DATASTAGE_INSTANCE_ID}\",\"users\":[],\"groups\":[{\"group_id\":${GROUP_ID},\"group_name\":\"${CP4D_ROLE_GROUP_NAME}\",\"role\":\"${CP4D_DATASTAGE_ROLE}\"}]}" | jq -r '. | .message')

    echo "Result adding CP4D Group \"${CP4D_ROLE_GROUP_NAME}\" to DataStage instance \"${CP4D_DATASTAGE_INSTANCE_NAME}\" with Role \"${CP4D_DATASTAGE_ROLE}\": ${ADD_GROUP_TO_DATASTAGE}"
else
    export CP4D_DATASTAGE_CURRENT_ROLE=$(jq -r ".data[] | select(.GroupName==\"${CP4D_ROLE_GROUP_NAME}\") | .Role" <<< ${CURRENT_GROUP_ASSIGNMENTS})

    if [ "${CP4D_DATASTAGE_CURRENT_ROLE}" == "${CP4D_DATASTAGE_ROLE}" ]; then
        echo "Group \"${CP4D_ROLE_GROUP_NAME}\" is already assigned DataStage instance \"${CP4D_DATASTAGE_INSTANCE_NAME}\" with role \"${CP4D_DATASTAGE_ROLE}\""
    else
        echo "Moving Group \"${CP4D_ROLE_GROUP_NAME}\" DataStage Role from \"${CP4D_DATASTAGE_CURRENT_ROLE}\" to \"${CP4D_DATASTAGE_ROLE}\""    

        export PATCH_GROUP_TO_DATASTAGE=$(curl -s -k -X PATCH -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS_ROLE} \
        -d "{\"serviceInstanceID\":\"${DATASTAGE_INSTANCE_ID}\",\"groupRoles\":[{\"group_id\":${GROUP_ID},\"newRole\":\"${CP4D_DATASTAGE_ROLE}\"}]}" | jq -r '. | .message')

        echo "Result patching CP4D Group \"${CP4D_ROLE_GROUP_NAME}\" to DataStage instance \"${CP4D_DATASTAGE_INSTANCE_NAME}\" to Role \"${CP4D_ROLE_GROUP_NAME}: ${PATCH_GROUP_TO_DATASTAGE}\""
    fi
fi

echo ""
echo "==> 5. DataStage instance group assignment completed"
echo ""
echo "=================="
echo "Returning with exit code 0"
echo ""
