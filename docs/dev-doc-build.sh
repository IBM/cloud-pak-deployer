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

$container_tool build -t cpd-doc .