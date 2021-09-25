#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage: "
    echo ""
    echo "assign_CA_authorization.sh"
    echo "  <CLOUD_PAK_FOR_DATA_URL>"
    echo "  <CLOUD_PAK_FOR_DATA_LOGIN_USER>"
    echo "  <CLOUD_PAK_FOR_DATA_LOGIN_PASSWORD>"
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>"
    echo "  <CLOUD_PAK_FOR_DATA_COGNOS_ANALYTICS_ROLE>"
    echo ""
    echo "Example command:"
    echo "./assign_CA_authorization.sh"
    echo "  https://......"
    echo "  admin"
    echo "  ******"
    echo "  \"Cognos User Group\""
    echo "  \"Analytics Viewer\""
    echo ""
    exit 0
fi

if [ "$#" -ne 5 ]; then
    echo "Incorrect number of parameters provided."
    echo "Run ./assign_CA_authorization.sh for help command"
    exit 1
fi

export CP4D_URL=$1
export CP4D_LOGIN_USER=$2
export CP4D_LOGIN_PASSWORD=$3
export CP4D_ROLE_GROUP_NAME=$4
export CP4D_CA_ROLE=$5

export CP4D_URL_AUTH=${CP4D_URL}/icp4d-api/v1/authorize
export CP4D_URL_CONFIG=${CP4D_URL}/usermgmt/v1/usermgmt/config
export CP4D_URL_GROUPS=${CP4D_URL}/usermgmt/v2/groups
export CP4D_URL_USER=${CP4D_URL}/usermgmt/v1/user
export CP4D_URL_USERS=${CP4D_URL}/usermgmt/v1/usermgmt/users
export CP4D_URL_LDAP_USERS=${CP4D_URL}/usermgmt/v2/ldap/users
export CP4D_INSTANCES=${CP4D_URL}/zen-data/v3/service_instances
export CP4D_INSTANCES_USERS=${CP4D_URL}/zen-data/v2/serviceInstance/users
export CP4D_INSTANCES_USERS_ROLE=${CP4D_INSTANCES_USERS}/role

#Default list of Cognos Analytics Roles
export CP4D_CA_ROLES=("Analytics Administrators" "Analytics Explorers" "Analytics Users" "Analytics Viewer")

echo ""
echo "==> Summarize task"
echo ""
echo "=================="
echo "IBM Cloud Pak for Data URL: ${CP4D_URL}"
echo "IBM Cloud Pak for Data User: ${CP4D_LOGIN_USER}"
echo "User Group Name: ${CP4D_ROLE_GROUP_NAME}" 
echo "Cognos Analyics assignment role: ${CP4D_CA_ROLE}"

echo ""
echo "==> 1. Authenticating via User and Password to Cloud Pak for Data and acquire Bearer token"
echo ""
echo "=================="
export BEARER=$(curl -s -k -X POST -H 'Content-Type: application/json' -d "{ \"username\":\"${CP4D_LOGIN_USER}\", \"password\":\"${CP4D_LOGIN_PASSWORD}\" }" $CP4D_URL_AUTH | jq -r '. | .token' )

if [ "${BEARER}" == "null" ]; then
    echo "Unable to acquire CP4D Bearer token with provided login credentials..."
    exit 1
fi

echo ""
echo "==> 2. Validate the provided Cognos Analytics role ${CP4D_CA_ROLE} is available in Cognos Analytics for Cloud Pak for Data"
echo ""
echo "=================="
if [[ ! " ${CP4D_CA_ROLES[@]} " =~ " ${CP4D_CA_ROLE} " ]]; then
    echo "Provided Role ${CP4D_CA_ROLE} is not part of the available roles in Cognos Analytics for Cloud Pak for Data."
    echo "Only the following Cognos Analytics roles are available in Cloud Pak for Data:"
    for CA_ROLE in "${CP4D_CA_ROLES[@]}"
    do
        echo " - ${CA_ROLE}"
    done    
    
    exit 1
fi

echo ""
echo "==> 3. Validate if LDAP configuration is present"
echo ""
echo "=================="
export CP4D_CONFIGURATION=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_CONFIG})
export LDAP_SERVER=$(echo ${CP4D_CONFIGURATION} | jq -r '. | .externalLDAPHost')

if [[ -z "${LDAP_SERVER}" || "${LDAP_SERVER}" == "null" ]]
then
    echo "No active LDAP configuration available in Cloud Pak for Data. Configure LDAP connectivity prior to running this script"
    exit 1
fi

echo ""
echo "==> 4. Validate if User Group \"${CP4D_ROLE_GROUP_NAME}\" already exists"
echo ""
echo "=================="
export GROUP_SEARCH=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS})
export GROUP_ID=$(echo ${GROUP_SEARCH} | jq -r ".results[] | select(.name==\"${CP4D_ROLE_GROUP_NAME}\") | .group_id")

if [ -z "$GROUP_ID" ]
then
    echo "CP4D User Group ${CP4D_ROLE_GROUP_NAME} does not exist. Ensure the User Group exists prior to running this script"
    exit 1
fi

echo ""
echo "==> 5. Get the list of LDAP Groups of User Group \"${CP4D_ROLE_GROUP_NAME}\""
echo ""
echo "=================="

export CP4D_URL_GROUP_MEMBERSHIP=${CP4D_URL_GROUPS}/${GROUP_ID}/membership_rules
export USER_GROUP_MEMBERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUP_MEMBERSHIP})

export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY=()

for LDAP_GROUP in $(jq -c ".results[] | .ldap_group" <<< ${USER_GROUP_MEMBERS}); do
  CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY+=("${LDAP_GROUP}")
  echo " - ${LDAP_GROUP}"
done

if [ ${#CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]} -lt 1 ]; then
  echo "CP4D User Group ${CP4D_ROLE_GROUP_NAME} has no LDAP groups assigned. Ensure the User Group is configured with at least 1 LDAP group prior to running this script"
  exit 1
fi

echo ""
echo "==> 6. Acquire Cognos Analytics Instance ID"
echo ""
echo "=================="
export COGNOS_INSTANCE_ID=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES} | jq -r ".service_instances[] | select(.addon_type==\"cognos-analytics-app\") | .id")

if [[ -z "$COGNOS_INSTANCE_ID" || "$COGNOS_INSTANCE_ID" == "null" ]]
then
    echo "Unable to fetch Cognos Analytics Instance ID. Ensure a Cognos Analytics instance is provisioned and running..."
    exit 1
else
    echo "Cloud Pak for Data Cognos Analytics ID: ${COGNOS_INSTANCE_ID}"
fi

echo ""
echo "==> 7. For each member of CP4D User Group \"${CP4D_ROLE_GROUP_NAME}\", check if user exists in Cloud Pak for Data"
echo "==> If the user does not exist, create the user"
echo ""
echo "=================="
export CURRENT_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_USERS})

for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"
do
    echo "Handling LDAP Group: ${LDAP_GROUP}"
   
    export LDAP_GROUP_MEMBERS=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_LDAP_USERS} \
        -d "{\"search_field\":\"ldap_group\",\"search_string\":${LDAP_GROUP}}")
    
    for LDAP_USER in $(jq -c ".[] | .username" <<< ${LDAP_GROUP_MEMBERS}); do

        export LDAP_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_DISPLAY_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .displayName" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_EMAIL=$(jq -r ".[] | select(.username==${LDAP_USER}) | .email" <<< ${LDAP_GROUP_MEMBERS})

        export CP4D_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${CURRENT_CP4D_USERS})

        if [ -z "$CP4D_USER_NAME" ]
        then
            echo "Cloud Pak for Data User ${LDAP_USER_NAME} does not exist, creating user..."

            if [[ -z $LDAP_USER_NAME || -z $LDAP_USER_DISPLAY_NAME || -z $LDAP_USER_EMAIL ]]; then
                echo "One of LDAP User Name, Display Name or email is empty, which is not permitted. Skipping user creation..."
                exit 1
            else
                export CP4D_USER_UID=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_USER} \
                    -d "{\"username\":\"${LDAP_USER_NAME}\",\"displayName\":\"${LDAP_USER_DISPLAY_NAME}\",\"email\":\"${LDAP_USER_EMAIL}\",\"authenticator\":\"external\",\"user_roles\":[\"zen_user_role\"]}" | jq -r '. | .uid')

                if [[ -z ${CP4D_USER_UID} || "${CP4D_USER_UID}" == "null " ]]
                then
                    echo "Error occurred when creating user ${LDAP_USER_NAME}"
                    exit 1
                fi

                echo "Created User ${LDAP_USER_NAME} with UID ${CP4D_USER_UID}"
            fi
        else
            export CP4D_USER_UID=$(jq -r ".[] | select(.username==${LDAP_USER}) | .uid" <<< ${CURRENT_CP4D_USERS})
            echo "Cloud Pak for Data User ${LDAP_USER_NAME} exists with UID ${CP4D_USER_UID}"
        fi
    done

    #Refresh CP4D Users in case a new users exists in multiple LDAP groups
    export CURRENT_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_USERS})
done

echo ""
echo "==> 8. For each member of CP4D User Group \"${CP4D_ROLE_GROUP_NAME}\", assign the role of \"${CP4D_CA_ROLE}\" to the Cognos Analytics Instance"
echo ""
echo "=================="
export CURRENT_CA_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS}?sID=${COGNOS_INSTANCE_ID})

for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"
do
    echo ""
    echo "Handling Cognos Analytics access for LDAP Group: ${LDAP_GROUP}"
   
    export LDAP_GROUP_MEMBERS=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_LDAP_USERS} \
        -d "{\"search_field\":\"ldap_group\",\"search_string\":${LDAP_GROUP}}")

    for LDAP_USER in $(jq -c ".[] | .username" <<< ${LDAP_GROUP_MEMBERS}); do

        export CP4D_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_DISPLAY_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .displayName" <<< ${LDAP_GROUP_MEMBERS})
        export CP4D_USER_UID=$(jq -r ".[] | select(.username==${LDAP_USER}) | .uid" <<< ${CURRENT_CP4D_USERS})
        
        export CP4D_CA_USER_NAME=$(jq -r ".requestObj[] | select(.UserName==${LDAP_USER}) | .UserName" <<< ${CURRENT_CA_CP4D_USERS})

        if [ -z "$CP4D_CA_USER_NAME" ]
        then
            echo "Cloud Pak for Data User ${LDAP_USER_DISPLAY_NAME} not yet assigned to Cognos Analytics instance, assigning user..."

            if [[ -z $CP4D_USER_NAME || -z $LDAP_USER_DISPLAY_NAME || -z $CP4D_USER_UID || "$CP4D_USER_NAME" == "null" || "$LDAP_USER_DISPLAY_NAME" == "null" || "$CP4D_USER_UID" == "null" ]]; then
                echo "One of CP4D User Name, Display Name or UID is empty, which is not permitted. Skipping user assignment to Cognos Analytics instance..."
            else
                export ADD_USER_TO_CA=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS} \
                    -d "{\"users\":[{\"uid\":\"${CP4D_USER_UID}\",\"username\":\"${LDAP_USER_NAME}\",\"display_name\":\"${LDAP_USER_DISPLAY_NAME}\",\"role\":\"${CP4D_CA_ROLE}\"}],\"serviceInstanceID\":\"${COGNOS_INSTANCE_ID}\"}" | jq -r '. | .message')

                echo "Result adding ${LDAP_USER_DISPLAY_NAME} to Cognos Analytics instance ${COGNOS_INSTANCE_ID} with Role ${CP4D_CA_ROLE}: ${ADD_USER_TO_CA}"
            fi
        else
            export CP4D_CA_CURRENT_ROLE=$(jq -r ".requestObj[] | select(.UserName==${LDAP_USER}) | .Role" <<< ${CURRENT_CA_CP4D_USERS})

            if [ "${CP4D_CA_CURRENT_ROLE}" == "${CP4D_CA_ROLE}" ]; then
                echo "User ${LDAP_USER_DISPLAY_NAME} is already assigned Cognos Analytics role ${CP4D_CA_ROLE}"
            else
                echo "Moving User ${LDAP_USER_DISPLAY_NAME} Cognos Analytics Role from ${CP4D_CA_CURRENT_ROLE} to ${CP4D_CA_ROLE}"

                export DELETE_CA_ROLE=$(curl -s -k -X DELETE -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS} \
                    -d "{\"users\":[\"${CP4D_USER_UID}\"],\"serviceInstanceID\":\"${COGNOS_INSTANCE_ID}\"}" | jq -r '. | .message')

                echo "Result Delete User ${LDAP_USER_DISPLAY_NAME} from instance ${COGNOS_INSTANCE_ID}: ${DELETE_CA_ROLE}"

                export ADD_USER_TO_CA=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS} \
                    -d "{\"users\":[{\"uid\":\"${CP4D_USER_UID}\",\"username\":\"${LDAP_USER_NAME}\",\"display_name\":\"${LDAP_USER_DISPLAY_NAME}\",\"role\":\"${CP4D_CA_ROLE}\"}],\"serviceInstanceID\":\"${COGNOS_INSTANCE_ID}\"}" | jq -r '. | .message')

                echo "Result adding ${LDAP_USER_DISPLAY_NAME} to Cognos Analytics instance ${COGNOS_INSTANCE_ID} with Role ${CP4D_CA_ROLE}: ${ADD_USER_TO_CA}"
            fi
        fi
    done

    #Refresh the current CA CP4D Users when handling multiple LDAP Groups
    export CURRENT_CA_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS}?sID=${COGNOS_INSTANCE_ID})
done

echo ""
echo "==> 9. Cognos Analytics user assignment completed"
echo ""
echo "=================="
echo "Returning with exit code 0"
echo ""
