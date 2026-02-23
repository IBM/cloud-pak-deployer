#!/bin/bash

pushd ..

podman build -t cpd-doc -f docs/Dockerfile .

popd