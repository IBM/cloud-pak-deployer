# Private registry

In cases where the OpenShift cluster is in an environment with limited internet connectivity, you may want OpenShift to pull Cloud Pak images from a private image registry (aka container registry). There may also be other reasons for choosing a private registry over the entitled registry.

## Configuring a private registry
The below steps outline how to configure a private registry for a Cloud Pak deployment. When the `image_registry` object is referenced by the Cloud Pak object (such as `cp4d`), the deployer makes the following changes in OpenShift so that images are pulled from the private registry:

* Global pull secret: The image registry's credentials are retrieved from the vault (the secret name must be `image-registry-<name>` and an entry for the registry is added to the global pull secret (secret `pull-secret` in project `openshift-config`).
* ImageContentSourcePolicy: This is a mapping between the original location of the image, for example `quay.io/opencloudio/zen-metastoredb@sha256:582cac2366dda8520730184dec2c430e51009a854ed9ccea07db9c3390e13b29` is mapped to `registry.coc.uk.ibm.com:15000/opencloudio/zen-metastoredb@sha256:582cac2366dda8520730184dec2c430e51009a854ed9ccea07db9c3390e13b29`.
* Image registry settings: OpenShift keeps image registry settings in custom resource `image.config.openshift.io/cluster`. If a private registry with a self-signed certificate is configured, certificate authority's PEM secret must be created as a configmap in the `openshift-config` project. The deployer uses the vault secret referenced in `registry_trusted_ca_secret` property to create or update the configmap so that OpenShift can connect to the registry in a secure manner. Alternatively, you add the `registry_insecure: true` property to pull images without checking the certificate.

## `image_registry`
Defines a private registry that will be used for pulling the Cloud Pak container images from. Additionally, if the Cloud Pak entitlement key was specified at run time of the deployer, the images defined by the case files will be mirrored to this private registry.
```
image_registry:
- name: cpd463
  registry_host_name: registry.example.com
  registry_port: 5000
  registry_insecure: false
  registry_trusted_ca_secret: cpd463-ca-bundle
```

#### Properties
| Property | Description                                                          | Mandatory | Allowed values |
| -------- | -------------------------------------------------------------------- | --------- | -------------- |
| name     | Name by which the image registry is identified.                      | Yes       |  |
| registry_host_name | Host name or IP address of the registry server             | Yes       |  |
| registry_port | Port that the image registry listens on. Default is the https port (443) | No | |
| registry_namespace | Namespace (path) within the registry that holds the Cloud Pak images. Mandatory only when using the IBM Cloud Container Registry (ICR)    | No       | |
| registry_insecure | Defines whether insecure registry access with a self-signed certificate is allowed | No       | True, False (default) |
| registry_trusted_ca_secret | Defines the vault secret which holds the certificate authority bundle that must be used when connecting to this private registry. This parameter cannot be specified if `registry_insecure` is also specified. | No       |  |

!!! warning
    The `registry_host_name` you specify in the `image_registry` definition must also be available for DNS lookup within OpenShift. If the registry runs on a server that is not registered in the DNS, use its IP address instead of a host name.

When mirroring images, the deployer connects to the registry using the host name and port. If the port is omitted, the standard https protocol (443) is used. If a `registry_namespace` is specified, for example when using the IBM Container Registry on IBM Cloud, it will be appended to the registry URL.

The user and password to connect to the registry will be retrieved from the vault, using secret `image-registry-<your_image_registry_name>` and must be stored in the format `registry_user:registry_password`. For example, if you want to connect to the image registry `cpd404` with user `admin` and password `very_s3cret`, you would create a secret as follows:
```
cp-deploy.sh vault set \
  -vs image-registry-cpd463 \
  -vsv "admin:very_s3cret"
```

If you need to connect to a private registry which is not signed by a public certificate authority, you have two choices:
* Store the PEM certificate that that holds the CA bundle in a vault secret and specify that secret for the `registry_trusted_ca_secret` property. This is the recommended method for private registries.
* Specify `registry_insecure: false` (not recommended): This means that the registry (and port) will be marked as insecure and OpenShift will pull images from it, even if its certificate is self-signed.

For example, if you have a file `/tmp/ca.crt` with the PEM certificate for the certificate authority, you can do the following:
```
cp-deploy.sh vault set \
  -vs cpd463-ca-bundle \
  -vsf /tmp/ca.crt
```

This will create a vault secret which the deployer will use to populate a `configmap` in the `openshift-config` project, which in turn is referenced by the `image.config.openshift.io/cluster` custom resource. For the above configuration, configmap `cpd404-ca-bundle` would be created and teh `image.config.openshift.io/cluster` would look something like this:
```
apiVersion: config.openshift.io/v1
kind: Image
metadata:
...
...
  name: cluster
spec:
  additionalTrustedCA:
    name: cpd463-ca-bundle
```

### Using the IBM Container Registry as a private registry
If you want to use a private registry when running the deployer for a ROKS cluster on IBM Cloud, you must use the IBM Container Registry (ICR) service. The deployer will automatically create the specified namespace in the ICR and set up the credentials accordingly. Configure an image_registry object with the host name of the private registry and the namespace that holds the images. An example of using the ICR as a private registry:

```
image_registry:
- name: cpd463
  registry_host_name: de.icr.io
  registry_namespace: cpd463
```

The registry host name must end with `icr.io` and the registry namespace is mandatory. No other properties are needed; the deployer will retrieve them from IBM Cloud.

If you have already created the ICR namespace, create a vault secret for the image registry credentials:
```
cp-deploy.sh vault set \
  -vs image-registry-cpd463
  -vsv "admin:very_s3cret"
```

An example of configuring the private registry for a `cp4d` object is below:
```
cp4d:
- project: cpd-instance
  openshift_cluster_name: {{ env_id }}
  cp4d_version: 4.8.3
  image_registry_name: cpd463
```

The Cloud Pak for Data installation refers to the `cpd463` `image_registry` object.

If the `ibm_cp_entitlement_key` secret is in the vault at the time of running the deployer, the required images will be mirrored from the entitled registry to the private registry. If all images are already available in the private registry, just specify the `--skip-mirror-images` flag when you run the deployer.

## Using a private registry for the Cloud Pak installation (non-IBM Cloud)
Configure an image_registry object with the host name of the private registry and some optional properties such as port number, CA certificate and whether insecure access to the registry is allowed.

Example:
```
image_registry:
- name: cpd463
  registry_host_name: registry.example.com
  registry_port: 5000
  registry_insecure: false
  registry_trusted_ca_secret: cpd463-ca-bundle
```

!!! warning
    The `registry_host_name` you specify in the `image_registry` definition must also be available for DNS lookup within OpenShift. If the registry runs on a server that is not registered in the DNS, use its IP address instead of a host name.

To create the vault secret for the image registry credentials:
```
cp-deploy.sh vault set \
  -vs image-registry-cpd463
  -vsv "admin:very_s3cret"
```

To create the vault secret for the CA bundle:
```
cp-deploy.sh vault set \
  -vs cpd463-ca-bundle
  -vsf /tmp/ca.crt
```

Where `ca.crt` looks something like this:
```
-----BEGIN CERTIFICATE-----
MIIFszCCA5ugAwIBAgIUT02v9OdgdvjgQVslCuL0wwCVaE8wDQYJKoZIhvcNAQEL
BQAwaTELMAkGA1UEBhMCVVMxETAPBgNVBAgMCE5ldyBZb3JrMQ8wDQYDVQQHDAZB
cm1vbmsxFjAUBgNVBAoMDUlCTSBDbG91ZCBQYWsxHjAcBgNVBAMMFUlCTSBDbG91
...
mcutkgtbkq31XYZj0CiM451Qp8KnTx0=
-----END CERTIFICATE-
```

An example of configuring the private registry for a `cp4d` object is below:
```
cp4d:
- project: cpd-instance
  openshift_cluster_name: {{ env_id }}
  cp4d_version: 4.8.3
  image_registry_name: cpd463
```

The Cloud Pak for Data installation refers to the `cpd463` `image_registry` object.

If the `ibm_cp_entitlement_key` secret is in the vault at the time of running the deployer, the required images will be mirrored from the entitled registry to the private registry. If all images are already available in the private registry, just specify the `--skip-mirror-images` flag when you run the deployer.