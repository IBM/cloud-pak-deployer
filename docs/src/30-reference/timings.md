# Timings for the deployment

## Duration of the overall deployment process

| Phase | Step  | Time in minutes | Comments |
| --- | ----  | -----:| --- |
| 10 - Validation |  | 3 | |
| | | | |
| 20 - Prepare | Generators    |  3 | |
| | | | |
| 30 - Provision infrastructure | Create VPC | 1 | |
|  | Create VSI without storage | 5 | |
|  | Create VSI with storage | 10 | |
|  | Create VPC ROKS cluster | 45 | |
|  | Install ROKS ODF add-on and create storage classes | 45 | |
| | | | |
| 40 - Configure infrastructure | Install NFS on VSIs | 10 | |
| | Create NFS storage classes | 5 | |
| | Create private container registry namespace | 5 | |
| | | | |
| 50 - Install Cloud Pak | Prepare OpenShift for Cloud Pak for Data install | 60 | During this step, the compute nodes may be replaced and also the Kubernetes services may be restarted. |
| | Mirror Cloud Pak for Data images to private registry (only done when using private registry) | 30-600 | If the entitled registry is used, this step will be skipped. When using a private registry, if images have already been mirrored, the duration will be much shorter, approximately 10 minutes. |
| | Install Cloud Pak for Data control plane | 20 | |
| | Create Cloud Pak for Data subscriptions for cartridges | 15 | |
| | Install cartridges | 20-300 | The amount of time really depends on the cartridges being installed. In the table below you will find an estimate of the installation time for each cartridge. Cartridges will be installed in parallel through the operators. |
| | | | |
| 60 - Configure Cloud Pak | Configure Cloud Pak for Data LDAP | 5 | |
| | Provision instances for cartridges | 30-60 | For cartridges that have instances defined. Creation of the instances will run in parallel where possible. |
| | Configure cartridge and instance permissions based on LDAP config | 10 | |
| | | | |
| 70 - Deploy assets | No activities yet | 0 | |
| 80 - Smoke tests | Show Cloud Pak for Data cluster details | 1 | |

## Cloud Pak for Data cartridge deployment

| Cartridge | Full name  | Installation time | Instance provisioning time | Dependencies |
| --- | ----  | -----:| ---: | --- |
| cpd_platform | Cloud Pak for Data control plane | 20 | N/A | |
| ccs | Common Core Services | 75 | N/A | |
| db2aas | Db2 as a Service | 30 | N/A | |
| iis | Information Server | 60 | N/A | ccs, db2aas |
| | | | | |
| ca | Cognos Analytics | 20 | 45 | ccs |
| planning-analytics | Planning Analytics | 15 | N/A | |
| watson_assistant | Watson Assistant | 70 | N/A | |
| watson-discovery | Watson Discovery | 100 | N/A | |
] watson-ks | Watson Knowledge Studio | 20 | N/A | |
| watson-speech | Watson Speech to Text and Text to Speech | 20 | N/A | |
| wkc | Watson Knowledge Catalog | 90 | N/A | ccs, db2aas, iis |
| wml | Watson Machine Learning | 45 | N/A | ccs |
| ws  | Watson Studio | 30 | N/A | ccs |

Examples:

* Cloud Pak for Data installation with just Cognos Analytics will take 20 (control plane) + 75 (ccs) + 20 (ca) + 45 (ca instance) = ~160 minutes
* Cloud Pak for Data installation with Cognos Analytics and Watson Studio will take 20 (control plane) + 75 (ccs) + 45 (ws+ca) + 45 (ca instance) = ~185 minutes
* Cloud Pak for Data installation with just Watson Knowledge Catalog will take 20 (control plane) + 75 (ccs) + 30 (db2aas) + 60 (iis) + 90 (wkc) = ~275 minutes
* Cloud Pak for Data installation with Watson Knowledge Catalog and Watson Studio will take the same time because WS will finish 30 minutes after installing CCS, while WKC will take a lot longer to complete


