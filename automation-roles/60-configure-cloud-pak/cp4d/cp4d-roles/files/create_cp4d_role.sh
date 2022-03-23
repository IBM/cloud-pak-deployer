#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage: "
    echo ""
    echo "create_cp4d_role.sh"
    echo "  <CLOUD_PAK_FOR_DATA_URL>"
    echo "  <CLOUD_PAK_FOR_DATA_BEARER_TOKEN>"
    echo "  <CLOUD_PAK_FOR_DATA_ROLE_NAME>"    
    echo "  <CLOUD_PAK_FOR_DATA_ROLE_DESCRIPTION>"
    echo "  <CLOUD_PAK_FOR_DATA_PERMISSION_LIST>"
    echo ""
    echo "Example command:"
    echo "./create_cp4d_role.sh"
    echo "  https://......"
    echo "  <bearer token>"
    echo "  \"my custom role\""
    echo "  \"my custom role description\""
    echo "  \"manage_project;manage_space\""
    echo ""
    exit 0
fi

if [ "$#" -ne 5 ]; then
    echo "Incorrect number of parameters provided."
    echo "Run ./create_cp4d_role.sh for help command"
    exit 1
fi

export CP4D_URL=$1
export CP4D_BEARER_TOKEN=$2
export CP4D_ROLE_NAME=$3
export CP4D_ROLE_DESCRIPTION=$4
export CP4D_ROLE_PERMISSIONS=$5

export CP4D_PERMISSIONS_URL=${CP4D_URL}/icp4d-api/v1/permissions
export CP4D_ROLES_URL=${CP4D_URL}/icp4d-api/v1/roles

#Create an array of the permissions
export CP4D_REQUEST_PERMISSIONS_ARRAY=(${CP4D_ROLE_PERMISSIONS//;/ })

echo ""
echo "==> 1. Get current available permissions in Cloud Pak for Data"
echo ""
echo "=================="
export CP4D_PERMISSIONS=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_PERMISSIONS_URL})
export CP4D_PERMISSIONS_ARRAY=()

for PERMISSION in $(jq -r ".Permissions[] | ." <<< ${CP4D_PERMISSIONS}); do
  CP4D_PERMISSIONS_ARRAY+=("${PERMISSION}")
  echo " - ${PERMISSION}"
done

echo ""
echo "==> 2. Validate if Provided permissions are existing permissions in Cloud Pak for Data"
echo ""
echo "=================="
for PERMISSION in "${CP4D_REQUEST_PERMISSIONS_ARRAY[@]}"; do
    if [[ ! " ${CP4D_PERMISSIONS_ARRAY[@]} " =~ " ${PERMISSION} " ]]; then
        echo "Provided Permissions \"${PERMISSION}\" is not part of the available permissions in Cloud Pak for Data."
        echo "Only permissions available in Cloud Pak for Data can be used."
        exit 1
    fi
done
echo "All requested roles are validated."

echo ""
echo "==> 3. Validate if role already exists"
echo ""
echo "=================="
export CP4D_ROLES=$(curl -s -k -X GET -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' ${CP4D_ROLES_URL})
export CP4D_ROLE_ID=$(echo ${CP4D_ROLES} | jq -r ".Roles[] | select(.role_name==\"${CP4D_ROLE_NAME}\") | .id")


if [ -z "$CP4D_ROLE_ID" ]; then

    echo ""
    echo "==> 4. Create the role if it does not exist"
    echo ""
    echo "=================="
    echo "Role \"${CP4D_ROLE_NAME}\" does not exist. Creating role..."

    export CP4D_ROLES_PERMISSION_REQUEST="["
    for PERMISSION in "${CP4D_REQUEST_PERMISSIONS_ARRAY[@]}"; do
        CP4D_ROLES_PERMISSION_REQUEST="${CP4D_ROLES_PERMISSION_REQUEST}\"${PERMISSION}\","
    done
    #Strip the last , character and add the closing ]
    CP4D_ROLES_PERMISSION_REQUEST="${CP4D_ROLES_PERMISSION_REQUEST::-1}]"
    
    CP4D_CREATE_ROLES_PAYLOAD="{\"role_name\":\"${CP4D_ROLE_NAME}\",\"description\":\"${CP4D_ROLE_DESCRIPTION}\",\"permissions\":${CP4D_ROLES_PERMISSION_REQUEST}}"

    export CP4D_CREATE_ROLE=$(curl -s -k -X POST -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' -d "${CP4D_CREATE_ROLES_PAYLOAD}" ${CP4D_ROLES_URL} | jq -r '. | ._messageCode_')

    if [  "${CP4D_CREATE_ROLE}" != "200" ]; then
        echo "Error. Failed to create role \"${CP4D_ROLE_NAME}\"."
        echo "Payload used: ${CP4D_CREATE_ROLES_PAYLOAD}"
        exit 1
    else
        echo "Successfully created role \"${CP4D_ROLE_NAME}\""
        exit 0
    fi

else
    echo ""
    echo "==> 4. Update existing role if changes are identified"
    echo ""
    echo "=================="
    echo "Role \"${CP4D_ROLE_NAME}\" already exists with role id \"${CP4D_ROLE_ID}\"."

    CP4D_ROLE_DEFINITION=$(echo ${CP4D_ROLES} | jq -r ".Roles[] | select(.role_name==\"${CP4D_ROLE_NAME}\") | .permissions")

    CP4D_PATCH_ROLE="false"
    for PERMISSION in $(jq -r ".[]" <<< ${CP4D_ROLE_DEFINITION}); do
        if [[ ! " ${CP4D_REQUEST_PERMISSIONS_ARRAY[@]} " =~ " ${PERMISSION} " ]]; then
            echo "Permission \"${PERMISSION}\" is assigned to role \"${CP4D_ROLE_NAME}\", but missing in the request"
            CP4D_PATCH_ROLE="true"
        fi
    done

    for PERMISSION in "${CP4D_REQUEST_PERMISSIONS_ARRAY[@]}"; do
        CURRENT_PERMISSION=$(jq -r ".[] | select(. ==\"${PERMISSION}\")" <<< ${CP4D_ROLE_DEFINITION})

        if [ -z "${CURRENT_PERMISSION}" ]; then
            echo "Permission \"${PERMISSION}\" is currently not yet assigned to role \"${CP4D_ROLE_NAME}\""
            CP4D_PATCH_ROLE="true"
        fi
    done

    if [ "$CP4D_PATCH_ROLE" == "true" ]; then
        echo "Change identified for role \"${CP4D_ROLE_NAME}\", updating role permissions..."

        export CP4D_ROLES_PERMISSION_REQUEST="["
        for PERMISSION in "${CP4D_REQUEST_PERMISSIONS_ARRAY[@]}"; do
            CP4D_ROLES_PERMISSION_REQUEST="${CP4D_ROLES_PERMISSION_REQUEST}\"${PERMISSION}\","
        done
        #Strip the last , character and add the closing ]
        CP4D_ROLES_PERMISSION_REQUEST="${CP4D_ROLES_PERMISSION_REQUEST::-1}]"
        
        CP4D_PATCH_ROLE_PAYLOAD="{\"role_name\":\"${CP4D_ROLE_NAME}\",\"description\":\"${CP4D_ROLE_DESCRIPTION}\",\"permissions\":${CP4D_ROLES_PERMISSION_REQUEST}}"

        CP4D_PATCH_ROLE=$(curl -s -k -X PUT -H "Authorization: Bearer ${CP4D_BEARER_TOKEN}" -H 'Content-Type: application/json' -d "${CP4D_PATCH_ROLE_PAYLOAD}" ${CP4D_ROLES_URL}/${CP4D_ROLE_ID} | jq -r '. | ._messageCode_')

        if [  "${CP4D_PATCH_ROLE}" != "200" ]; then
            echo "Error. Failed to patch role \"${CP4D_ROLE_NAME}\"."
            echo "Payload used: ${CP4D_PATCH_ROLE_PAYLOAD}"
            exit 1
        else
            echo "Successfully patched role \"${CP4D_ROLE_NAME}\""
            exit 0
        fi
    else
        echo "No changes identified for role \"${CP4D_ROLE_NAME}\". No patch required...."
        exit 0
    fi
fi
