#!/bin/bash

podman rm -f cpd-doc 2>/dev/null
podman run --name cpd-doc -d -p 8000:8000 -v $PWD:/docs:Z cpd-doc:latest
podman logs -fl