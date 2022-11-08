#!/bin/bash

source /root/.bashrc

cd /doc

echo "Cleaning up old artifacts..."
rm -rf node_modules .cache package-lock.json public

echo "Installing the required Node.js modules..."
npm i apollo-boost graphql react-apollo -S
npm install

echo "Installing Gatsby..."
npm install -g gatsby-cli@4

echo "Starting the rendering process..."
npm run dev