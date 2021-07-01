#!/bin/bash

export CP4D_URL=$1
export CP4D_LOGIN_USER=$2
export CP4D_LOGIN_PASSWORD=$3
export CP4D_ROLE_GROUP_NAME=$4
export CP4D_ROLE_GROUP_DESCRIPTION=$5
export CP4D_ROLE_GROUP_IDENTIFIERS=$6
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING=$7
export CP4D_CA_ROLE=$8

export CP4D_URL_AUTH=${CP4D_URL}/icp4d-api/v1/authorize
export CP4D_URL_GROUPS=${CP4D_URL}/usermgmt/v2/groups
export CP4D_URL_ROLES=${CP4D_URL}/usermgmt/v1/roles
export CP4D_URL_USER=${CP4D_URL}/usermgmt/v1/user
export CP4D_URL_USERS=${CP4D_URL}/usermgmt/v1/usermgmt/users
export CP4D_URL_LDAP_USERS=${CP4D_URL}/usermgmt/v2/ldap/users
export CP4D_INSTANCES=${CP4D_URL}/zen-data/v3/service_instances
export CP4D_INSTANCES_USERS=${CP4D_URL}/zen-data/v2/serviceInstance/users
export CP4D_URL_ROLES

export CP4D_CA_ROLES=("")


#Create an array of the CP4D_ROLE_GROUP_IDENTIFIERS
export CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY=(${CP4D_ROLE_GROUP_IDENTIFIERS//;/ })

#Create an Array of [x,y,z] used in the request to CP4D for the Role Groups
export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="["
for ROLE in "${CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY[@]}"; do
    export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}\"${ROLE}\"," 
done
export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST::-1}]"

#Create an array of the CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY=(${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING//;/ })

#Create an Array of [x,y,z] used in the request to CP4D for the LDAP Group mapping
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="["
for ROLE in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"; do
    export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST}\"${ROLE}\"," 
done
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST::-1}]"

echo ${CP4D_URL}
echo ${CP4D_LOGIN_USER}
echo ${CP4D_LOGIN_PASSWORD}
echo ${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}
echo ${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST}

echo ""
echo "==> 1. Authenticating via User and Password to Cloud Pak for Data and acquire Bearer token"
echo ""
echo "=================="
export BEARER=$(curl -s -k -X POST -H 'Content-Type: application/json' -d "{ \"username\":\"${CP4D_LOGIN_USER}\", \"password\":\"${CP4D_LOGIN_PASSWORD}\" }" $CP4D_URL_AUTH | jq -r '. | .token' )


echo ""
echo "==> 2. Get All available Cloud Pak for Data roles"
echo ""
echo "=================="
export CP4D_ROLES_RESPONSE=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_ROLES})
export CP4D_ROLES=()

for CP4D_ROLE in $(jq -r ".rows[] | .id" <<< ${CP4D_ROLES_RESPONSE}); do
    CP4D_ROLES+=(${CP4D_ROLE})
done

echo "The following roles are available in Cloud Pak for Data:"
for ROLE in "${CP4D_ROLES[@]}"
do
     echo " - ${ROLE}"
done

echo ""
echo "==> 3. Validate the provided role(s) are available in Cloud Pak for Data"
echo ""
echo "=================="
for ROLE in "${CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY[@]}"; do
    if [[ ! " ${CP4D_ROLES[@]} " =~ " ${ROLE} " ]]; then
        echo "Provided Role ${ROLE} is not part of the available roles in Cloud Pak for Data."
        echo "Only roles available in Cloud Pak for Data can be used."
        exit 1
    fi
done

exit

echo ""
echo "==> 2. Validate if User Group ${CP4D_ROLE_GROUP_NAME} already exists"
echo ""
echo "=================="
export GROUP_SEARCH=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS})
export GROUP_ID=$(echo ${GROUP_SEARCH} | jq -r ".results[] | select(.name==\"${CP4D_ROLE_GROUP_NAME}\") | .group_id")

echo ""
echo "==> 3. Create CP4D User Group ${CP4D_ROLE_GROUP_NAME} if it does not exist"
echo ""
echo "=================="
if [ -z "$GROUP_ID" ]
then
    export GROUP_ID=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS} \
        -d "{\"name\":\"${CP4D_ROLE_GROUP_NAME}\",\"description\":\"${CP4D_ROLE_GROUP_DESCRIPTION}\",\"role_identifiers\":${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}}" | jq -r '. | .group_id')

    export CPD_URL_MEMBERS=${CP4D_URL}/usermgmt/v2/groups/${GROUP_ID}/members

    export CP4D_ASSIGN_LDAP_GROUP=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CPD_URL_MEMBERS} \
        -d "{\"ldap_groups\":${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING},\"user_identifiers\":[]}")
else
    echo "CP4D User Group ${CP4D_ROLE_GROUP_NAME} already exists. Skipping creation..."
fi

echo ""
echo "==> 4. Acquire Cognos Analytics Instance ID"
echo ""
echo "=================="
export COGNOS_INSTANCE_ID=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES} | jq -r ".service_instances[] | select(.addon_type==\"cognos-analytics-app\") | .id")

if [ -z "$CP4D_CA_USER_NAME" ]
then
    echo "Unable to fetch Cognos Analytics Instance ID. Ensure an instance is provisioned..."
    exit 1
fi

echo ""
echo "==> 5. Display Cognos Analytics ID"
echo ""
echo "=================="
echo "CP4D Cognos Analytics ID: ${COGNOS_INSTANCE_ID}"

echo ""
echo "==> 6. For each member of CP4D User Group ${CP4D_ROLE_GROUP_NAME}, check if user exists in CP4D"
echo "==> If the user does not exist, create the user"
echo ""
echo "=================="
export CURRENT_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_USERS})

for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"
do
    echo "Handling LDAP Group: ${LDAP_GROUP}"
   
    export LDAP_GROUP_MEMBERS=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_LDAP_USERS} \
        -d "{\"search_field\":\"ldap_group\",\"search_string\":\"${LDAP_GROUP}\"}")
    
    for LDAP_USER in $(jq -c ".[] | .username" <<< ${LDAP_GROUP_MEMBERS}); do

        export LDAP_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_DISPLAY_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .displayName" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_EMAIL=$(jq -r ".[] | select(.username==${LDAP_USER}) | .email" <<< ${LDAP_GROUP_MEMBERS})

        echo "Validating: ${LDAP_USER_NAME} - ${LDAP_USER_DISPLAY_NAME} - ${LDAP_USER_EMAIL}"

        export CP4D_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${CURRENT_CP4D_USERS})

        if [ -z "$CP4D_USER_NAME" ]
        then
            echo "Cloud Pak for Data User ${LDAP_USER_NAME} does not exist, creating user..."

            if [[ -z $LDAP_USER_NAME || -z $LDAP_USER_DISPLAY_NAME || -z $LDAP_USER_EMAIL ]]; then
                echo "One of LDAP User Name, Display Name or email is empty, which is not permitted. Skipping user creation..."
                exit 1
            else
                export CP4D_USER_UID=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_USER} \
                    -d "{\"username\":\"${LDAP_USER_NAME}\",\"displayName\":\"${LDAP_USER_DISPLAY_NAME}\",\"email\":\"${LDAP_USER_EMAIL}\",\"user_roles\":${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST},\"authenticator\":\"external\"}" | jq -r '. | .uid')
                
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
echo "==> 7. For each member of CP4D User Group ${CP4D_ROLE_GROUP_NAME}, assign the role of ${CP4D_CA_ROLE} to the Cognos Analytics Instance"
echo ""
echo "=================="
export CURRENT_CA_CP4D_USERS=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS}?sID=${COGNOS_INSTANCE_ID})

for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"
do
    echo "Handling Cognos Analytics access for LDAP Group: ${LDAP_GROUP}"
   
    export LDAP_GROUP_MEMBERS=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_LDAP_USERS} \
        -d "{\"search_field\":\"ldap_group\",\"search_string\":\"${LDAP_GROUP}\"}")

    for LDAP_USER in $(jq -c ".[] | .username" <<< ${LDAP_GROUP_MEMBERS}); do

        export CP4D_USER_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .username" <<< ${LDAP_GROUP_MEMBERS})
        export LDAP_USER_DISPLAY_NAME=$(jq -r ".[] | select(.username==${LDAP_USER}) | .displayName" <<< ${LDAP_GROUP_MEMBERS})
        export CP4D_USER_UID=$(jq -r ".[] | select(.username==${LDAP_USER}) | .uid" <<< ${CURRENT_CP4D_USERS})
        
        export CP4D_CA_USER_NAME=$(jq -r ".requestObj[] | select(.UserName==${LDAP_USER}) | .UserName" <<< ${CURRENT_CA_CP4D_USERS})

        if [ -z "$CP4D_CA_USER_NAME" ]
        then
            echo "Cloud Pak for Data User ${LDAP_USER_DISPLAY_NAME} not yet assigned to Cognos Analytics instance, assigning user..."

            if [[ -z $CP4D_USER_NAME || -z $LDAP_USER_DISPLAY_NAME || -z $CP4D_USER_UID ]]; then
                echo "One of CP4D User Name, Display Name or UID is empty, which is not permitted. Skipping user assignment to Cognos Analytics instance..."
            else
                export ADD_USER_TO_CA=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_INSTANCES_USERS} \
                    -d "{\"users\":[{\"uid\":\"${CP4D_USER_UID}\",\"username\":\"${LDAP_USER_NAME}\",\"display_name\":\"${LDAP_USER_DISPLAY_NAME}\",\"role\":\"${CP4D_CA_ROLE}\"}],\"serviceInstanceID\":\"${COGNOS_INSTANCE_ID}\"}" | jq -r '. | .message')

                echo "Result adding ${LDAP_USER_DISPLAY_NAME} to Cognos Analytics instance ${COGNOS_INSTANCE_ID}: ${ADD_USER_TO_CA}"
            fi
        else
            echo "Cloud Pak for Data User ${LDAP_USER_DISPLAY_NAME} already assigned to Cognos Analytics instance..."
        fi
    done
done


