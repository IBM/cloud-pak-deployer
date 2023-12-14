#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# Determine the project that runs the operators
oc get project ibm-common-services > /dev/null 2>&1
if [ $? -eq 0 ];then
  fs_project="ibm-common-services"
else
  fs_project=cpd-operators"
fi

echo "Listing subscriptions and their CSVs"
oc get sub -n ${fs_project} \
    --sort-by=.metadata.creationTimestamp \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{","}{.status.installedCSV}{","}{.status.state}{"\n"}{end}'