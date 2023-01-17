#!/bin/bash

echo "Deleting container if it exists"
podman rm -f cpd-doc 2> /dev/null

echo "Run documentation container"
podman run --name cpd-doc -d -p 8000:8000 -v $PWD:/doc:Z cpd-doc:latest

echo "Tail logs"
podman logs -fl