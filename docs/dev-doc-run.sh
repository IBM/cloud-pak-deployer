#!/bin/bash

SELINUX_OPTION=""
if hash getenforce 2>/dev/null; then
  SELINUXSTATUS=$(getenforce)
  if [ "$SELINUXSTATUS" != "Disabled" ]; then
    SELINUX_OPTION=":z"
  fi
fi

podman rm -f cpd-doc 2>/dev/null
PROCESS=$(podman run --name cpd-doc -d -p 8000:8000 -v $PWD:/cloud-pak-deployer-docs/docs${SELINUX_OPTION} cpd-doc:latest)
podman logs -f ${PROCESS}