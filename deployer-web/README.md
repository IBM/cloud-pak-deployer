# Getting Started with React App

This project was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

## Prerequisites

- Git is installed
- Node.js 16/18/19 is installed. If Node.js is not installed, please refer to section [Install Node.js](#install-nodejs) to install node.js.

## Install Node.js

1. To **install** or **update** NodeJS Package Manager and the uv Python package manager.

On Linux:
```sh
yum install -y npm
yum install -y uv
```

On MacOS:
```sh
brew install npm
brew install uv
```

## Getting started, run the application in development mode

You need 2 terminals for the application to run in test-mode, one for the web server and one for the React application.

Install:
```sh
make install
```

Web server:
```sh
make test-web-server
```

Web UI:
```sh
make test-web-ui
```

This runs the app in the development mode. Open [http://localhost:3000](http://localhost:3000) to view it in your browser.
The page will reload when you make changes. You may also see any lint errors in the console.

You can simply stop the web server and the React application using ^C.

# Build application for production

Before shipping the UI in the deployer for production, make sure you build the production server.

```sh
make install
make build
```