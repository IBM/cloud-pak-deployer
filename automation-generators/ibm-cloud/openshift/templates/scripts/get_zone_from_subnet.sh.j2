#!/bin/bash

eval "$(jq -r '@sh "export REGION=\(.region) IDENTIFIER=\(.identifier) TOKEN=\(.token)"')"


response=`curl -s -X GET "https://${REGION}.iaas.cloud.ibm.com/v1/subnets/${IDENTIFIER}?version=2021-05-18&generation=2" -H "Authorization: ${TOKEN}"`

zone_name=$(echo ${response} | jq -r '.zone.name')

jq -n --arg zone_name "${zone_name}" '{ "zone_name": $zone_name }'
