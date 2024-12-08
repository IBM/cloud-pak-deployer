# Using a private registry

Some environments, especially in situations where the OpenShift cannot directly connect to the internet, require a private registry for OpenShift to pull the Cloud Pak images from. The Cloud Pak Deployer can mirror images from the entitled registry to a private registry that you want to use for the Cloud Pak(s). Also, if infrastructure which holds the OpenShift cluster is fully disconnected from the internet, the Cloud Pak Deployer can build a registry which can be stored on a portable hard disk or pen drive and then shipped to the site.

!!! info
    Note: In all cases, the deployer can work behind a proxy to access the internet. Go to [Running behind proxy](#running-behind-a-proxy) for more information.

The below instructions are not limited to disconnected (air-gapped) OpenShift clusters, but are more generic for deployment using a private registry.

There are three use cases for mirroring images to a private registry and using this to install the Cloud Pak(s):

* [Use case 1 - Mirror images and install using a bastion server](#use-case-1---mirror-images-and-install-using-a-bastion-server). The bastion server can connect to the internet (directly or via a proxy), to OpenShift and to the private registry used by the OpenShift cluster.
* [Use case 2 - Mirror images with a connected server, install using a bastion](#use-case-2---mirror-images-with-an-internet-connected-server-install-using-a-bastion). The connected server can connect to the internet and to the private registry used by the OpenShift cluster. The server cannot connect to the OpenShift cluster. The bastion server can connect to the private registry and to the OpenShift cluster.
* [Use case 3 - Mirror images using a portable image registry](#use-case-3---mirror-images-using-a-portable-image-registry). The private registry used by the OpenShift cluster cannot be reached from the server that is connected to the internet. You need a portable registry to download images and which you then ship to a server that can connect to the **existing** OpenShift cluster and its private registry.

Use cases 1 and 3 are also outlined in the Cloud Pak for Data installation documentation: https://www.ibm.com/docs/en/cloud-paks/cp-data/4.5.x?topic=tasks-mirroring-images-your-private-container-registry

For specifying a private registry in the Cloud Pak Deployer configuration, please see [Private registry](../../../30-reference/configuration/private-registry). Example of specifying a private registry with a self-signed certificate in the configuration:
``` { .yaml .copy }
image_registry:
- name: cpd453
  registry_host_name: registry.coc.ibm.com
  registry_port: 5000
  registry_insecure: True
```

The `cp4d` instance must reference the `image_registry` object using the `image_registry_name`:
``` { .yaml .copy }
cp4d:
- project: zen-45
  openshift_cluster_name: {{ env_id }}
  cp4d_version: 4.5.3
  openshift_storage_name: ocs-storage
  image_registry_name: cpd453
```

!!! info
    The deployer only supports using a private registry for the Cloud Pak images, not for OpenShift itself. Air-gapped installation of OpenShift is currently not in scope for the deployer.

!!! warning
    The `registry_host_name` you specify in the `image_registry` definition must also be available for DNS lookup within OpenShift. If the registry runs on a server that is not registered in the DNS, use its IP address instead of a host name.

The main 3 directories that are needed for both types of air-gapped installations are:

* Cloud Pak Deployer directory: `cloud-pak-deployer`
* Configuration directory: The directory that holds a all the Cloud Pak Deployer configuration
* Status directory: The directory that will hold all downloads, vault secrets and the portable registry when applicable (use case 3)

Fpr use cases 2 and 3, where the directories must be shipped to the air-gapped cluster, the **Cloud Pak Deployer** and **Configuration** directories will be stored in the **Status** directory for simplicity.

## Use case 1 - Mirror images and install using a bastion server
This is effectively "not-air-gapped" scenario, where the following conditions apply:

* The private registry is hosted inside the private dloud
* The bastion server can connect to the internet and mirror images to the private image registry
* The bastion server is optionally connected to the internet via a proxy server. See [Running behind a proxy](#running-behind-a-proxy) for more details
* The bastion server can connect to OpenShift

![Not-air-gapped](images/not-air-gapped.png)

### On the bastion server

The bastion server is connected to the internet and OpenShift cluster.

* If there are restrictions regarding the internet sites that can be reached, ensure that the website domains the deployer needs are whitelisted. For a list of domains, check [locations to whitelist](../../50-advanced/locations-to-whitelist)
* If a proxy server is configured for the bastion node, check the settings (`http_proxy`, `https_proxy`, `no_proxy` environment variables)
* Build the Cloud Pak Deployer image using `./cp-deploy.sh build`
* Create or update the directory with the configuration; make sure all your Cloud Paks and cartridges are specified as well as an `image_registry` entry to identify the private registry
* Export the CONFIG_DIR and STATUS_DIR environment variables to respectively point to the configuration directory and the status directory
* Export the CP_ENTITLEMENT_KEY environment variable with your Cloud Pak entitlement key
* Create a vault secret `image-registry-<name>` holding the connection credentials for the private registry specified in the configuration (`image_registry`). For example for a registry definition with name `cpd453`, create secret `image-registry-cpd453`.
``` { .bash .copy }
./cp-deploy.sh vault set \
    -vs image-registry-cpd453 \
    -vsv "admin:very_s3cret"
```

* Set the environment variable for the `oc login` command. For example:
``` { .bash .copy }
export CPD_OC_LOGIN="oc login api.pluto-01.coc.ibm.com:6443 -u kubeadmin -p BmxQ5-KjBFx-FgztG-gpTF3 --insecure-skip-tls-verify"
```

* Run the `./cp-deploy.sh env apply` command to start deployment of the Cloud Pak to the OpenShift cluster. For example:
``` { .bash .copy }
./cp-deploy.sh env apply
```
The existence of the `image_registry` definition and its reference in the `cp4d` definition instruct the deployer to mirror images to the private registry and to configure the OpenShift cluster to pull images from the private registry. If you have already mirrored the Cloud Pak images, you can add the `--skip-mirror-images` parameter to speed up the deployment process.

## Use case 2 - Mirror images with an internet-connected server, install using a bastion
This use case is also sometimes referred to as "semi-air-gapped", where the following conditions apply:

* The private registry is hosted outside of the private cloud that hosts the bastion server and OpenShift
* An internet-connected server external to the private cloud can reach the entitled registry and the private registry
* The internet-connected server is optionally connected to the internet via a proxy server. See [Running behind a proxy](#running-behind-a-proxy) for more details
* The bastion server **cannot** connect to the internet
* The bastion server can connect to OpenShift

![Semi-air-gapped](images/semi-air-gapped.png)

!!! warning
    Please note that in this case the Cloud Pak Deployer expects an OpenShift cluster to be available already and will only work with an `existing-ocp` configuration. The bastion server does not have access to the internet and can therefore not instantiate an OpenShift cluster.

### On the internet-connected server

* If there are restrictions regarding the internet sites that can be reached, ensure that the website domains the deployer needs are whitelisted. For a list of domains, check [locations to whitelist](../../50-advanced/locations-to-whitelist)
* If a proxy server is configured for the internet-connected server, check the settings (`http_proxy`, `https_proxy`, `no_proxy` environment variables)
* Build the Cloud Pak Deployer image using `./cp-deploy.sh build`
* Create or update the directory with the configuration; make sure all your Cloud Paks and cartridges are specified as well as an `image_registry` entry to identify the private registry
* Export the CONFIG_DIR and STATUS_DIR environment variables to respectively point to the configuration directory and the status directory
* Export the CP_ENTITLEMENT_KEY environment variable with your Cloud Pak entitlement key
* Create a vault secret `image-registry-<name>` holding the connection credentials for the private registry specified in the configuration (`image_registry`). For example for a registry definition with name `cpd453`, create secret `image-registry-cpd453`.
``` { .bash .copy }
./cp-deploy.sh vault set \
    -vs image-registry-cpd453 \
    -vsv "admin:very_s3cret"
```
If the status directory does not exist it is created at this point.

#### Diagram step 1
* Run the deployer using the `./cp-deploy.sh env download --skip-portable-registry` command. For example:
``` { .bash .copy }
./cp-deploy.sh env download \
    --skip-portable-registry
```
This will download all clients to the status directory and then mirror images from the entitled registry to the private registry. If mirroring fails, fix the issue and just run the `env download` again.

* Before saving the status directory, you can optionally remove the entitlement key from the vault:
``` { .bash .copy }
./cp-deploy.sh vault delete \
    -vs ibm_cp_entitlement_key
```

#### Diagram step 2
When the download finished successfully, the status directory holds the deployer scripts, the configuration directory and the deployer container image.

#### Diagram step 3
Ship the status directory from the internet-connected server to the bastion server.

You can use tar with gzip mode or any other compression technique. The total size of the directories should be relatively small, typically < 5 GB

### On the bastion server
The bastion server is not connected to the internet but is connected to the private registry and the OpenShift cluster.

#### Diagram step 4
We're using the instructions in [Run on existing OpenShift](../../10-use-deployer/3-run/existing-openshift), adding the `--air-gapped` and `--skip-mirror-images` flags, to start the deployer:

* Restore the status directory onto the bastion server
* Export the STATUS_DIR environment variable to point to the status directory
* Untar the `cloud-pak-deployer` scripts, for example:
``` { .bash .copy }
tar xvzf $STATUS_DIR/cloud-pak-deployer.tar.gz
```

* Set the CPD_AIRGAP environment variable to `true`
``` { .bash .copy }
export CPD_AIRGAP=true
```

* Set the environment variable for the `oc login` command. For example:
``` { .bash .copy }
export CPD_OC_LOGIN="oc login api.pluto-01.coc.ibm.com:6443 -u kubeadmin -p BmxQ5-KjBFx-FgztG-gpTF3 --insecure-skip-tls-verify"
```

* Run the `cp-deploy.sh env apply --skip-mirror-images` command to start deployment of the Cloud Pak to the OpenShift cluster. For example:
``` { .bash .copy }
cd cloud-pak-deployer
./cp-deploy.sh env apply \
    --skip-mirror-images
```   

The `CPD_AIRGGAP` environment variable tells the deployer it will not download anything from the internet; `--skip-mirror-images` indicates that images are already available in the private registry that is included in the configuration (`image_registry`)

## Use case 3 - Mirror images using a portable image registry
This use case is also usually referred to as "air-gapped", where the following conditions apply:

* The private registry is hosted in the private cloud that hosts the bastion server and OpenShift
* The bastion server **cannot** connect to the internet
* The bastion server can connect to the private registry and the OpenShift cluster
* The internet-connected server **cannot** connect to the private cloud
* The internet-connected server is optionally connected to the internet via a proxy server. See [Running behind a proxy](#running-behind-a-proxy) for more details
* You need a portable registry to fill the private registry with the Cloud Pak images

![Air-gapped using portable registry](images/air-gapped-portable.png)

!!! warning
    Please note that in this case the Cloud Pak Deployer expects an OpenShift cluster to be available already and will only work with an `existing-ocp` configuration. The bastion server does not have access to the internet and can therefore not instantiate an OpenShift cluster.

### On the internet-connected server

* If there are restrictions regarding the internet sites that can be reached, ensure that the website domains the deployer needs are whitelisted. For a list of domains, check [locations to whitelist](../../../50-advanced/locations-to-whitelist)
* If a proxy server is configured for the bastion node, check the settings (`http_proxy`, `https_proxy`, `no_proxy` environment variables)
* Build the Cloud Pak Deployer image using `cp-deploy.sh build`
* Create or update the directory with the configuration, making sure all your Cloud Paks and cartridges are specified
* Export the CONFIG_DIR and STATUS_DIR environment variables to respectively point to the configuration directory and the status directory
* Export the CP_ENTITLEMENT_KEY environment variable with your Cloud Pak entitlement key

#### Diagram step 1

* Run the deployer using the `./cp-deploy.sh env download` command. For example:
``` { .bash .copy }
./cp-deploy.sh env download
```
This will download all clients, start the portable registry and then mirror images from the entitled registry to the **portable registry**. The portable registry data is kept in the status directory. If mirroring fails, fix the issue and just run the `env download` again.

* Before saving the status directory, you can optionally remove the entitlement key from the vault:
``` { .bash .copy }
./cp-deploy.sh vault delete \
    -vs ibm_cp_entitlement_key
```

See the download of watsonx.ai in action: https://ibm.box.com/v/cpd-air-gapped-download

#### Diagram step 2
When the download finished successfully, the status directory holds the deployer scripts, the configuration directory, the deployer container image and the portable registry.

#### Diagram step 3
Ship the status directory from the internet-connected server to the bastion server.

You can use tar with gzip mode or any other compression technique. The status directory now holds all assets required for the air-gapped installation and its size can be substantial (100+ GB). You may want to use multi-volume tar files if you are using network transfer. 

### On the bastion server
The bastion server is not connected to the internet but is connected to the private registry and OpenShift cluster.

#### Diagram step 4

See the air-gapped installation of Cloud Pak for Data in action: https://ibm.box.com/v/cpd-air-gapped-install. For the demonstration video, the download of the previous step has first been re-run to only download the Cloud Pak for Data control plane to avoid having to ship and upload ~700 GB.

We're using the instructions in [Run on existing OpenShift](../../10-use-deployer/3-run/existing-openshift), adding the CPD_AIRGAP environment variable.

* Restore the status directory onto the bastion server. Make sure the volume to which you restore has enough space to hold the entire status directory, which includes the portable registry.
* Export the STATUS_DIR environment variable to point to the status directory
* Untar the `cloud-pak-deployer` scripts, for example:
``` { .bash .copy }
tar xvzf $STATUS_DIR/cloud-pak-deployer.tar.gz
cd cloud-pak-deployer
```

* Set the CPD_AIRGAP environment variable to `true`
``` { .bash .copy }
export CPD_AIRGAP=true
```

* Set the environment variable for the `oc login` command. For example:
``` { .bash .copy }
export CPD_OC_LOGIN="oc login api.pluto-01.coc.ibm.com:6443 -u kubeadmin -p BmxQ5-KjBFx-FgztG-gpTF3 --insecure-skip-tls-verify"
```

* Create a vault secret `image-registry-<name>` holding the connection credentials for the private registry specified in the configuration (`image_registry`). For example for a registry definition with name `cpd453`, create secret `image-registry-cpd453`.
``` { .bash .copy }
./cp-deploy.sh vault set \
    -vs image-registry-cpd453 \
    -vsv "admin:very_s3cret"
```

* Run the `./cp-deploy.sh env apply` command to start deployment of the Cloud Pak to the OpenShift cluster. For example:
``` { .bash .copy }
./cp-deploy.sh env apply
```  
The `CPD_AIRGGAP` environment variable tells the deployer it will not download anything from the internet. As a first action, the deployer mirrors images from the portable registry to the private registry included in the configuration (`image_registry`)


## Running behind a proxy
If the Cloud Pak Deployer is run from a server that has the HTTP proxy environment variables set up, i.e. "proxy" environment variables are configured on the server and in the terminal session, it will also apply these settings in the deployer container. 

The following environment variables are automatically applied to the deployer container if set up in the session running the `cp-deploy.sh` command:

* `http_proxy`
* `https_proxy`
* `no_proxy`

If you do not want the deployer to use the proxy environment variables, you must remove them before running the `cp-deploy.sh` command:
``` { .bash .copy }
unset http_proxy
unset https_proxy
unset no_proxy
```

## Special settings for debug and DaemonSet images in air-gapped mode
Specifically when running the deployer on IBM Cloud ROKS, certain OpenShift settings must be applied using DaemonSets in the `kube-system` namespace. Additionally, the deployer uses the `oc debug node` commands to retrieve `kubelet` and `crio` configuration files from the compute nodes.

The default container images used by the DaemonSets and `oc debug node` commands are based on Red Hat's Universal Base Image and will be pulled from Red Hat registries. This is typically not possible in air-gapped installations, hence different images must be used. It is your responsibility to copy suitable (preferably UBI) images to an image registry that is connected to the OpenShift cluster. Also, if a pull secret is needed to pull the image(s) from the registry, you must create the associated secret in the `kube-system` OpenShift project.

To configure alternative container images for the deployer to use, set the following properties in the `.inv` file kept in your configuration's `inventory` directory, or specify them as additional command line parameters for the `cp-deploy.sh` command. 

If you do not set these values, the deployer assumes that the default images are used for DaemonSet and `oc debug node`.

| Property             | Description                                            | Example                        |
| -------------------- | ------------------------------------------------------ | ------------------------------ |
| cpd_oc_debug_image   | Container image to be used for the `oc debug` command. | `registry.redhat.io/rhel8/support-tools:latest` |
| cpd_ds_image         | Container image to be used for the DaemonSets that configure Kubelet, etc. | `icr.io/cpopen/cpd/olm-utils-v3:latest` |
