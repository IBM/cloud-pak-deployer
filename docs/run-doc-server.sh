#!/bin/bash

cd /cloud-pak-deployer-docs/docs

echo "Cleaning up old artifacts..."
make clean

echo "Building documentation..."
make build

echo "Starting the mkdocs server..."
make serve