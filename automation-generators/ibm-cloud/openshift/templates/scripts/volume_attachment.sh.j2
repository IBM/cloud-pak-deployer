#!/bin/bash

ibmcloud api cloud.ibm.com
ibmcloud login -q --apikey ${IBMCLOUD_API_KEY}
export TOKEN=$(ibmcloud iam oauth-tokens --output json | jq -r '.iam_token')

# Before creating, check to see if attachment for volume is already present
if ! RESPONSE=$(curl -s -X GET \
        -H "Authorization: $TOKEN" \
        -H "Content-Type: application/json" \
        -H "X-Auth-Resource-Group-ID: $RESOURCE_GROUP_ID" \
        "https://$REGION.containers.cloud.ibm.com/v2/storage/getAttachments?cluster=$CLUSTER_ID&worker=$WORKER_ID"
); then
  echo "Error when trying to /getAttachments"
  exit 1
fi

ID=$(echo $RESPONSE | jq -r --arg VOLUMEID "$VOLUME_ID" '.volume_attachments[] | select(.volume.id==$VOLUMEID) | .id')

# If should create attachment, create attachment
if [ "$ID" == "" ] || [ "$ID" == "null" ]; then
    if ! RESPONSE=$(
        curl -s -X POST "https://containers.cloud.ibm.com/global/v2/storage/createAttachment" \
          -H "accept: application/json" \
          -H "Authorization: $TOKEN" \
          -H "X-Auth-Resource-Group-ID: $RESOURCE_GROUP_ID" \
          -H "Content-Type: application/json" \
          -d "{  \"cluster\": \"${CLUSTER_ID}\",  \"volumeID\": \"${VOLUME_ID}\",  \"worker\": \"${WORKER_ID}\" }"
    ); then
      echo "Error when trying to /createAttachment"
      exit 1
    fi

    ID=$(echo $RESPONSE | jq -r .id)

    if [ "$ID" == "" ] || [ "$ID" == "null" ]; then
        echo "/createAttachment did not work: $RESPONSE"
        exit 1
    fi
    echo "Created attachment for $CLUSTER_ID, $WORKER_ID and $VOLUME_ID: $ID"
    echo 'Sleeping for 1 minute...'
    sleep 1m # it takes some seconds for the attachment to stabilize and propagate
else
  echo "Attachment already exists: $RESPONSE"
fi
