#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )


# Check if PROJECT_CPD_INST_OPERATORS and PROJECT_CPD_INST_OPERANDS are set, otherwise throw an error
if [ -z "${PROJECT_CPD_INST_OPERATORS}" ] || [ -z "${PROJECT_CPD_INST_OPERANDS}" ]; then
  echo "Error: Environment variables PROJECT_CPD_INST_OPERATORS or PROJECT_CPD_INST_OPERANDS are not set."
  echo "Please source the cpd_vars file or define them"
  exit 1
fi

#Operators Project
fs_project=${PROJECT_CPD_INST_OPERATORS}

# List subscriptions and their CSVs
if oc get project ${fs_project} > /dev/null 2>&1; then
  echo "Listing subscriptions and their CSVs"
  oc get sub -n ${fs_project} \
      --sort-by=.metadata.creationTimestamp \
      --no-headers \
      -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{","}{.status.installedCSV}{","}{.status.state}{"\n"}{end}'
else
  echo "Error: Project ${fs_project} does not exist or cannot be accessed."
  exit 1
fi