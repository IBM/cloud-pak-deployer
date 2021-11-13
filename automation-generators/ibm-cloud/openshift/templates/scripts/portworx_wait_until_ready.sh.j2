#!/bin/bash

echo 'This script waits until Portworx is ready'
echo 'Sleeping 2m...'
sleep 2m

SLEEP_TIME="15s"
LIMIT=100


# Check if pods are ready

if ! DESIRED=$(kubectl get -n kube-system ds/portworx -o jsonpath='{.status.desiredNumberScheduled}'); then
  echo 'Error getting DESIRED pods'
  exit 1
fi

while true; do
  if ! READY=$(kubectl get -n kube-system ds/portworx -o jsonpath='{.status.numberReady}'); then
    echo 'Error getting READY pods'
  else
    echo "$READY out of $DESIRED pods are ready"
    
    if [ "$DESIRED" -eq "$READY" ]; then
      break;
    fi
  fi
  

  echo "Sleeping $SLEEP_TIME..."
  sleep $SLEEP_TIME
  
  (( i++ ))
  if [ "$i" -eq "$LIMIT" ]; then
    echo "Timed out."
    exit 1
  fi
done

# Check if Portworx is ready

if ! PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}'); then
  echo 'Error getting PX_POD'
  exit 1
fi

i=0

while true; do
  if ! STATUS=$(kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status --json | jq -r '.status'); then
    echo 'Error getting STATUS'
    exit 1
  fi
  
  echo "Portworx status: $STATUS"
  
  if [ "$STATUS" == "STATUS_OK" ]; then
    break
  fi
  
  echo "Sleeping $SLEEP_TIME..."
  sleep $SLEEP_TIME
  
  (( i++ ))
  if [ "$i" -eq "$LIMIT" ]; then
    echo "Timed out."
    exit 1
  fi
done

echo "=== Portworx is ready ==="
