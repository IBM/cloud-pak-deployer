#!/bin/bash

echo "Custom resources found in OpenShift project $1:"
oc get $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' --namespace $1

echo "Deleting Cloud Pak for Data control plane"
oc delete Ibmcpd --all --namespace $1 --ignore-not-found

echo "Deleting Cloud Pak for data namespace"
oc delete ns $1 --grace-period 300  --ignore-not-found
