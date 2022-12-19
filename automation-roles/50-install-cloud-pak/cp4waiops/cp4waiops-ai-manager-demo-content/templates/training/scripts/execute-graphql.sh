#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
# DO NOT MODIFY BELOW	
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	


echo "***************************************************************************************************************************************"
echo "  🔐  Getting credentials"
echo "***************************************************************************************************************************************"
if [[  $WAIOPS_NAMESPACE == "" ]]; then
    # Get Namespace from Cluster 
    echo "   ------------------------------------------------------------------------------------------------------------------------------"
    echo "   🔬 Getting Installation Namespace"
    echo "   ------------------------------------------------------------------------------------------------------------------------------"
    export WAIOPS_NAMESPACE=$(oc get po -A|grep aiops-orchestrator-controller |awk '{print$1}')
    echo "       ✅ AI Manager:         OK - $WAIOPS_NAMESPACE"
else
    echo "       ✅ AI Manager:         OK - $WAIOPS_NAMESPACE"
fi


if [[ ! $ROUTE =~ "ai-platform-api" ]]; then
      echo "       🛠️   Create Route"
      oc create route passthrough ai-platform-api -n $WAIOPS_NAMESPACE  --service=aimanager-aio-ai-platform-api-server --port=4000 --insecure-policy=Redirect --wildcard-policy=None
      export ROUTE=$(oc get route -n $WAIOPS_NAMESPACE ai-platform-api  -o jsonpath={.spec.host})
fi
      echo "        Route: $ROUTE"
      echo ""

if [[ $ZEN_TOKEN == "" ]]; then
      echo "       🛠️   Getting ZEN Token"
     
      ZEN_API_HOST=$(oc get route -n $WAIOPS_NAMESPACE cpd -o jsonpath='{.spec.host}')
      ZEN_LOGIN_URL="https://${ZEN_API_HOST}/v1/preauth/signin"
      LOGIN_USER=admin
      LOGIN_PASSWORD="$(oc get secret admin-user-details -n $WAIOPS_NAMESPACE -o jsonpath='{ .data.initial_admin_password }' | base64 --decode)"

      ZEN_LOGIN_RESPONSE=$(
      curl -k \
      -H 'Content-Type: application/json' \
      -XPOST \
      "${ZEN_LOGIN_URL}" \
      -d '{
            "username": "'"${LOGIN_USER}"'",
            "password": "'"${LOGIN_PASSWORD}"'"
      }' 2> /dev/null
      )

      ZEN_LOGIN_MESSAGE=$(echo "${ZEN_LOGIN_RESPONSE}" | jq -r .message)

      if [ "${ZEN_LOGIN_MESSAGE}" != "success" ]; then
            echo "Login failed: ${ZEN_LOGIN_MESSAGE}"
            exit 2
      fi

      ZEN_TOKEN=$(echo "${ZEN_LOGIN_RESPONSE}" | jq -r .token)
      #echo "${ZEN_TOKEN}"
      echo "Sucessfully logged in" 
      echo ""
fi

QUERY_FILE_PATH=$FILE_PATH/$FILE_NAME
echo "     "	
echo "      📥 Launch Query for file: $QUERY_FILE_PATH"	
echo "     "
QUERY="$(cat $QUERY_FILE_PATH)"
JSON_QUERY=$(echo "${QUERY}" | jq -sR '{"operationName": null, "variables": {}, "query": .}')



export result=$(curl -XPOST "https://$ROUTE/graphql" -k \
-H 'Accept-Encoding: gzip, deflate, br'  \
-H 'Content-Type: application/json'  \
-H 'Accept: application/json'  \
-H 'Connection: keep-alive'  \
-H 'DNT: 1'  \
-H "Origin: https://$ROUTE"  \
-H "authorization: Bearer $ZEN_TOKEN"  \
--data-binary "${JSON_QUERY}"  \
--compressed)

echo "      🔎 Result: "
echo "       "$result|jq ".data" | sed 's/^/          /'
echo "     "	
echo "     "	
