# Getting Started with Create React App

This project was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

## Prerequisites

- Git is installed
- Node.js 16/18/19 is installed. If Node.js is not installed, please refer to section [Install Node.js](#install-nodejs) to install node.js.

## Install Node.js

1. To **install** or **update** nvm, please run the following cURL or Wget command:
```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
```
```sh
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
```

Running either of the above commands downloads a script and runs it. The script clones the nvm repository to `~/.nvm`, and attempts to add the source lines from the snippet below to the correct profile file (`~/.bash_profile`, `~/.zshrc`, `~/.profile`, or `~/.bashrc`).

<a id="profile_snippet"></a>
```sh
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
```

2. Use the nvm command to install node.js. 
```sh
nvm install <node.js version>
```
For example:
```sh
nvm install 16.15.1
```

## Getting started, run the application in development mode

1. Open your terminal and then type
    ```sh
    git clone --depth=1 https://github.com/IBM/cloud-pak-deployer.git
    ```
    This clones the repo cloud-pak-deployer. 

2. cd into the ui folder and type
    ```sh
    cd cloud-pak-deployer/deployer-web/ui/
    ```

3. Install the required dependencies
    ```sh
    npm install
    ```

4. To run the React project in development mode
    ```sh
    npm start
    ```
This runs the app in the development mode. Open [http://localhost:3000](http://localhost:3000) to view it in your browser.
The page will reload when you make changes. You may also see any lint errors in the console.

Alternatively, run the React project in interactive watch mode
```sh
npm test
```

Launches the test runner in the interactive watch mode. See the section about [running tests](https://facebook.github.io/create-react-app/docs/running-tests) for more information.

## Build the application for production

1. Open your terminal and then type
    ```sh
    git clone --depth=1 https://github.com/IBM/cloud-pak-deployer.git
    ```
    This clones the repo cloud-pak-deployer. 

2. cd into the ui folder and type
    ```sh
    cd cloud-pak-deployer/deployer-web/ui/
    ```

3. Install the required dependencies
    ```sh
    rm -rf node_modules
    npm install
    ```

4. Build the production application
    ```sh
    npm run build
    ```

5. Copy the build to the served folder
    ```sh
    cp -r build/* ../ww/
    ```