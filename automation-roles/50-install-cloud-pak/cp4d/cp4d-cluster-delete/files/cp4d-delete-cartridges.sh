#!/bin/bash

echo "Custom resources found in OpenShift project $1:"
oc get $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' --namespace $1

echo "Deleting all custom resources except for CommonService, Ibmcpd, OperandRequest, ZenService"
for cr in \
    $(oc get $(oc api-resources --namespaced=true --verbs=list -o name \
        | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found \
        -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' \
        --no-headers --namespace $1 | awk '{print $1}' | grep -vi -E 'comonservice|ibmcpd|operandrequest|zenservice');do
    oc delete $cr --all --namespace $1 --grace-period 300
done