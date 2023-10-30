# Open a command line within the Cloud Pak Deployer container

Sometimes you may need to access the OpenShift cluster using the OpenShift client. For convenience we have made the `oc` command available in the Cloud Pak Deployer and you can start exploring the current OpenShift cluster immediately without having to install the client on your own workstation.

## Prepare for the command line

### Set environment variables
Make sure you have set the **CONFIG_DIR** and **STATUS_DIR** environment variables to the same values when you ran the `env apply` command. This will ensure that the `oc` command will access the OpenShift cluster(s) of that configuration.


### Optional: prepare OpenShift cluster
If you have not run the deployer yet and do not intend to install any Cloud Paks, but you do want to access the OpenShift cluster from the command line to check or prepare items, run the deployer with the `--skip-cp-install` flag.

```
./cp-deploy.sh env apply --skip-cp-install
```

Deployer will check the configuration, download clients, attempt to login to OpenShift and prepare the OpenShift cluster with the global pull secret and (for Cloud Pak for Data) node settings. After that the deployer will finish without installing any Cloud Pak.

## Run the Cloud Pak Deployer command line
```
./cp-deploy.sh env cmd 
```

You should see something like this:
```
-------------------------------------------------------------------------------
Entering Cloud Pak Deployer command line in a container.
Use the "exit" command to leave the container and return to the hosting server.
-------------------------------------------------------------------------------
Installing OpenShift client
Current OpenShift context: cpd
```

Now, you can check the OpenShift cluster version:
```
[root@Cloud Pak Deployer Container ~]$ oc get clusterversion
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.8.14    True        False         2d3h    Cluster version is 4.8.14
```

Or, display the list of OpenShift projects:
```
[root@Cloud Pak Deployer Container ~]$ oc get projects | grep -v openshift-
NAME                                               DISPLAY NAME   STATUS
calico-system                                                     Active
default                                                           Active
ibm-cert-store                                                    Active
ibm-odf-validation-webhook                                        Active
ibm-system                                                        Active
kube-node-lease                                                   Active
kube-public                                                       Active
kube-system                                                       Active
openshift                                                         Active
services                                                          Active
tigera-operator                                                   Active
cpd                                                            Active
```

## Exit the command line
Once finished, exit out of the container.
```
exit
```