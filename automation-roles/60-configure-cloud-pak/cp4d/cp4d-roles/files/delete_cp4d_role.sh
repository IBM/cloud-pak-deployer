#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage: "
    echo ""
    echo "delete_cp4d_role.sh"
    echo "  <CLOUD_PAK_FOR_DATA_URL>"
    echo "  <CLOUD_PAK_FOR_DATA_BEARER_TOKEN>"
    echo "  <CLOUD_PAK_FOR_DATA_ROLE_NAME>"    
    echo ""
    echo "Example command:"
    echo "./delete_cp4d_role.sh"
    echo "  https://......"
    echo "  <bearer token>"
    echo "  \"my custom role\""
    echo ""
    exit 0
fi

if [ "$#" -ne 3 ]; then
    echo "Incorrect number of parameters provided."
    echo "Run ./delete_cp4d_role.sh for help command"
    exit 1
fi

export CP4D_URL=$1
export CP4D_BEARER_TOKEN=$2
export CP4D_ROLE_NAME=$3

export CP4D_ROLES_WITH_COUNT_URL="${CP4D_URL}/usermgmt/v1/roles?include_platform_users_count=true&include_user_groups_count=true"
export CP4D_ROLES_URL=${CP4D_URL}/icp4d-api/v1/roles

echo ""
echo "==> 1. Get current available roles with users and group counts in Cloud Pak for Data"
echo ""
echo "=================="
export CP4D_ROLES=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_ROLES_WITH_COUNT_URL})

export CP4D_ROLE_ID=$(echo ${CP4D_ROLES} | jq -r ".rows[] | select(.doc.role_name==\"${CP4D_ROLE_NAME}\") | .id")


if [ -z "${CP4D_ROLE_ID}" ]; then
    echo "Cloud Pak for Data Role \"${CP4D_ROLE_NAME}\" not found..."
    exit 0
else
    echo "Found role \"${CP4D_ROLE_NAME}\" with role id \"${CP4D_ROLE_ID}\""
fi

export CP4D_ROLE_LINKED_USERS=$(echo ${CP4D_ROLES} | jq -r ".rows[] | select(.doc.role_name==\"${CP4D_ROLE_NAME}\") | .platform_users_count")

if [[ -z "${CP4D_ROLE_LINKED_USERS}" || "${CP4D_ROLE_LINKED_USERS}" == "null" || ${CP4D_ROLE_LINKED_USERS} -gt 0 ]]; then
    echo "Role \"${CP4D_ROLE_NAME}\" still has ${CP4D_ROLE_LINKED_USERS} platform users assigned. Unable to delete role."
    exit 1
fi

export CP4D_ROLE_LINKED_USER_GROUP=$(echo ${CP4D_ROLES} | jq -r ".rows[] | select(.doc.role_name==\"${CP4D_ROLE_NAME}\") | .user_groups_count")

if [[ -z "${CP4D_ROLE_LINKED_USER_GROUP}" || "${CP4D_ROLE_LINKED_USER_GROUP}" == "null" || ${CP4D_ROLE_LINKED_USER_GROUP} -gt 0 ]]; then
    echo "Role \"${CP4D_ROLE_NAME}\" still has ${CP4D_ROLE_LINKED_USER_GROUP} user groups assigned. Unable to delete role."
    exit 1
fi

echo ""
echo "==> 2. Delete Role \"${CP4D_ROLE_NAME}\""
echo ""
echo "=================="
echo "No Platform Users or Groups associated with Role \"${CP4D_ROLE_NAME}\". Deleting role..."

CP4D_DELETE_ROLE=$(curl -s -k -X DELETE -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_ROLES_URL}/${CP4D_ROLE_ID} | jq -r '. | ._messageCode_')

if [  "${CP4D_DELETE_ROLE}" != "200" ]; then
    echo "Error. Failed to delete role \"${CP4D_ROLE_NAME}\"."
    exit 1
else
    echo "Successfully deleted role \"${CP4D_ROLE_NAME}\""
    exit 0
fi


