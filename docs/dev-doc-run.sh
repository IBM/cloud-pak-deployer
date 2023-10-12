#!/bin/bash

# Check if Podman is available
if command -v podman &> /dev/null; then
    container_tool="podman"
elif command -v docker &> /dev/null; then
    container_tool="docker"
else
    echo "Neither Podman nor Docker is installed."
    exit 1
fi

$container_tool rm -f cpd-doc 2>/dev/null
$container_tool run --name cpd-doc -d -p 8000:8000 -v $PWD:/docs:Z cpd-doc:latest
$container_tool logs -fl