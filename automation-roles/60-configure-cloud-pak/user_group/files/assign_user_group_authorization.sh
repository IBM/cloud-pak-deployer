if [ "$#" -eq 0 ]; then
    echo ""
    echo "Usage: "
    echo ""
    echo "assign_user_group_authorization.sh"
    echo "  <CLOUD_PAK_FOR_DATA_URL>"
    echo "  <CLOUD_PAK_FOR_DATA_LOGIN_USER>"
    echo "  <CLOUD_PAK_FOR_DATA_LOGIN_PASSWORD>"
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_NAME>"
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_DESCRIPTION>"
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_ROLES_ASSIGNMENT>"
    echo "  <CLOUD_PAK_FOR_DATA_USER_GROUP_LDAP_GROUPS_MAPPING>"
    echo ""
    echo "Example command:"
    echo "./assign_user_group_authorization.sh"
    echo "  https://......"
    echo "  admin"
    echo "  ******"
    echo "  \"DataStage User Group\""
    echo "  \"User Group for DataStage Users\""
    echo "  \"zen_administrator_role\""
    echo "  \"cn=datastage_group,ou=groups,dc=ibm,dc=com\""
    echo ""
    echo "<CLOUD_PAK_FOR_DATA_USER_GROUP_ROLES_ASSIGNMENT>: Use a ; seperated list to assign multiple roles"
    echo "<CLOUD_PAK_FOR_DATA_USER_GROUP_LDAP_GROUPS_MAPPING>: Use a ; seperated list to assign multiple ldap groups"
    exit 0
fi

if [ "$#" -ne 7 ]; then
    echo "Incorrect number of parameters provided."
    echo "Run ./assign_user_group_authorization.sh for help command"
    exit 1
fi

#Read all input parameters
export CP4D_URL=$1
export CP4D_LOGIN_USER=$2
export CP4D_LOGIN_PASSWORD=$3
export CP4D_ROLE_GROUP_NAME=$4
export CP4D_ROLE_GROUP_DESCRIPTION=$5
export CP4D_ROLE_GROUP_ROLE_ASSIGNMENTS=$6
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPINGS=$7

#Construct all CP4D URLs used during the user group authorization assignment
export CP4D_URL_AUTH=${CP4D_URL}/icp4d-api/v1/authorize
export CP4D_URL_CONFIG=${CP4D_URL}/usermgmt/v1/usermgmt/config
export CP4D_URL_GROUPS=${CP4D_URL}/usermgmt/v2/groups
export CP4D_URL_ROLES=${CP4D_URL}/usermgmt/v1/roles
export CP4D_URL_USER=${CP4D_URL}/usermgmt/v1/user
export CP4D_URL_LDAP_GROUPS=${CP4D_URL}/usermgmt/v2/ldap/groups

#Create an array of the CP4D_ROLE_GROUP_IDENTIFIERS
export CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY=(${CP4D_ROLE_GROUP_ROLE_ASSIGNMENTS//;/ })
export CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY_LENGTH=${#CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY[@]}

if [[ -z "${CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY_LENGTH}" || ${CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY_LENGTH} -lt 1 ]]; then
 echo "No Role Group assigmnents provided..."
 exit 1
fi

#Create an Array of [x,y,z] used in the request to CP4D for the Role Groups
export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="["
for ROLE in "${CP4D_ROLE_GROUP_IDENTIFIERS_ARRAY[@]}"; do
    export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}\"${ROLE}\"," 
done
export CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST="${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST::-1}]"

#Create an array of the CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY=(${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPINGS//;/ })
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY_LENGTH=${#CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}

if [[ -z "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY_LENGTH}" || ${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY_LENGTH} -lt 1 ]]; then
 echo "No LDAP Mapping Groups provided..."
 exit 1
fi

#Create an Array of [x,y,z] used in the request to CP4D for the LDAP Group mapping
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="["
for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"; do
    export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST}\"${LDAP_GROUP}\"," 
done
export CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST="${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST::-1}]"

echo ""
echo "==> Summarize task"
echo ""
echo "=================="
echo "IBM Cloud Pak for Data URL: ${CP4D_URL}"
echo "IBM Cloud Pak for Data User: ${CP4D_LOGIN_USER}"
echo "User Group Name: ${CP4D_ROLE_GROUP_NAME}" 
echo "User Group Desription: ${CP4D_ROLE_GROUP_DESCRIPTION}" 
echo "User Group Role(s) assignments: ${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}"
echo "User Group LDAP Group(s) assignments: ${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST}"

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

echo ""
echo "==> 4. Validate if LDAP configuration is present"
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
echo "==> 5. Validate if all provided LDAP groups are existing LDAP groups"
echo ""
echo "=================="
for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"; do
    export LDAP_CN_NAME=${LDAP_GROUP%%,*}
    export LDAP_CN_NAME=${LDAP_CN_NAME:3}

    export LDAP_GROUP_SEARCH=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_LDAP_GROUPS} \
        -d "{\"search_string\":\"${LDAP_CN_NAME}\",\"limit\":100}" | jq -r ".[] |  select(.name==\"${LDAP_CN_NAME}\") | .name")

    if [ -z "${LDAP_GROUP_SEARCH}" ]
    then
        echo "LDAP Group ${LDAP_GROUP} is not found in LDAP registry. Make sure the LDAP group exists.."
        exit 1
    else
        echo "LDAP Group ${LDAP_GROUP} is an existing LDAP Group"
    fi
done

echo ""
echo "==> 6. Validate if User Group \"${CP4D_ROLE_GROUP_NAME}\" already exists"
echo ""
echo "=================="
export GROUP_SEARCH=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS})
export GROUP_ID=$(echo ${GROUP_SEARCH} | jq -r ".results[] | select(.name==\"${CP4D_ROLE_GROUP_NAME}\") | .group_id")

echo ""
echo "==> 7. Create CP4D User Group \"${CP4D_ROLE_GROUP_NAME}\" if it does not exist"
echo "If the User Group does not exist, create it with the role assigment(s)"
echo "If the User Group does exist, ensure the provide LDAP Groups are assigned to the User Group"
echo ""
echo "=================="
if [ -z "$GROUP_ID" ]
then
    export GROUP_ID=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CP4D_URL_GROUPS} \
        -d "{\"name\":\"${CP4D_ROLE_GROUP_NAME}\",\"description\":\"${CP4D_ROLE_GROUP_DESCRIPTION}\",\"role_identifiers\":${CP4D_ROLE_GROUP_IDENTIFIERS_FOR_REQUEST}}" | jq -r '. | .group_id')

    if [ "${GROUP_ID}" == "null" ]; then
        echo "Unable to create Group ${CP4D_ROLE_GROUP_NAME}, empty group id returned..."
        exit 1
    else 
        echo "Group ${CP4D_ROLE_GROUP_NAME} with group id ${GROUP_ID} created successfully..."
    fi

    export CPD_URL_MEMBERS=${CP4D_URL}/usermgmt/v2/groups/${GROUP_ID}/members

    export CP4D_ASSIGN_LDAP_GROUP=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CPD_URL_MEMBERS} \
        -d "{\"ldap_groups\":${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_FOR_REQUEST},\"user_identifiers\":[]}")
else
    echo "Cloud Pak for Data User Group ${CP4D_ROLE_GROUP_NAME} already exists. Validate LDAP group assignments..."

    export CPD_URL_MEMBERSHIPS=${CP4D_URL}/usermgmt/v2/groups/${GROUP_ID}/membership_rules
    export CPD_URL_MEMBERS=${CP4D_URL}/usermgmt/v2/groups/${GROUP_ID}/members

    export GROUP_MEMBERSHIP_RULES=$(curl -s -k -X GET -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CPD_URL_MEMBERSHIPS})

    for LDAP_GROUP in "${CP4D_ROLE_GROUP_LDAP_GROUP_MAPPING_ARRAY[@]}"
    do
        export LDAP_GROUP_LINKED=$(jq -r ".results[] | select(.ldap_group==\"${LDAP_GROUP}\") | .ldap_group" <<< ${GROUP_MEMBERSHIP_RULES})

        if [[ -z "${LDAP_GROUP_LINKED}" || "${LDAP_GROUP_LINKED}" == "null" ]]; then

            export CP4D_ASSIGN_LDAP_GROUP=$(curl -s -k -X POST -H "Authorization: Bearer ${BEARER}" -H 'Content-Type: application/json' ${CPD_URL_MEMBERS} \
              -d "{\"ldap_groups\":[\"${LDAP_GROUP}\"],\"user_identifiers\":[]}")

            echo "LDAP Group \"${LDAP_GROUP}\" added as a member of the User Role Group"
        else
            echo "LDAP Group \"${LDAP_GROUP}\" is already assigned as a member of the User Role Group"
        fi
    done
fi

echo ""
echo "==> 8. User Group authorization assignment completed"
echo ""
echo "=================="
echo "Returning with exit code 0"
echo ""