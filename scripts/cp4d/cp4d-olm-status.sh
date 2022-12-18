#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

fs_project=ibm-common-services

echo "Listing subscriptions and their CSVs"
oc get sub -n ${fs_project} \
    --sort-by=.metadata.creationTimestamp \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{","}{.status.installedCSV}{","}{.status.state}{"\n"}{end}'