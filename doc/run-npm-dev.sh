#!/bin/bash

source /root/.bashrc

cd /doc

echo "Installing the required Node.js modules..."
npm install

echo "Installing Gatsby..."
npm install -g gatsby-cli

echo "Starting the rendering process..."
npm run dev