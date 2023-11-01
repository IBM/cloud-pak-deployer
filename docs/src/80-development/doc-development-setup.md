# Documentation Development setup

Mkdocs themes encapsulate all of the configuration and implementation details of static documentation sites. This GitHub repository has been built with a dependency on the Mkdocs tool. This GiHub repository is connected to GitHub Actions; any commit to the `main` branch will cause a build of the GitHub pages to be triggered. The preferred method of working while developing documentation is to use the tooling from a loacal system

## Local tooling installation
If you want to test the documentation pages you're developing, it is best to run Mkdocs in a container and map your local `docs` folder to a folder inside the container. This avoids having to install nvm and many modules on your workstation.

Do the following:

* Make sure you have cloned this repository to your development server
* Start from the main directory of the cloud-pak-deployer repository
```
cd docs
./dev-doc-build.sh
```

This will build a Red Hat UBI image with all requirements pre-installed. It will take ~2-10 minutes to complete this step, dependent on your network bandwidth.

## Running the documentation image
```
./dev-doc-run.sh
```

This will start the container as a daemon and tail the logs. Once running, you will see the following message:
```output
...
INFO     -  Documentation built in 3.32 seconds
INFO     -  [11:55:49] Watching paths for changes: 'src', 'mkdocs.yml'
INFO     -  [11:55:49] Serving on http://0.0.0.0:8000/cloud-pak-deployer/...
```

## Starting the browser
Now that the container has fully started, it automatically tracks all changes under the `docs` folder and updates the pages site automatically. You can view the site by opening a browswer for URL:

http://localhost:8000

## Stopping the documentation container
If you don't want to test your changes locally anymore, stop the docker container.
```
podman kill cpd-doc
```

Next time you want to test your changes, re-run the `./dev-doc-run.sh`, which will delete the container, delete cache and build the documentation.

## Removing the docker container and image
If you want to remove all from your development server, do the following:
```
podman rm -f cpd-doc
podman rmi -f cpd-doc:latest
```

Note that after merging your updated documentation with the `main` branch, the pages site will be rendered by a GitHub action. Go to GitHub Actions if you want to monitor the build process.
