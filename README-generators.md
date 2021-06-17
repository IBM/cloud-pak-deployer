# Generators Role

The sample playbook is **playbook-sample-run-generators.yaml**. It will make use of the folders: 

* sample-generators/environment_definitions
* sample-generators/generator_config

The first one contains definitions. One file contains exact one environment definition. No multifile support, yet.

The second one contains all the generators. They are triggered like roles. The toplevel-key in the **sample-generators/environment_definitions/sample.yaml** map to the names of the generators contained in **sample-generators/generator_config/generators**. 

The generators-role in **automation-roles/preprocess/generators** will just iterate over the elements contained under each toplevel-key inside the **sample.yaml** and pass the defined attributes to the main.yaml of each generator. From there on the generators behave like simple task-collections. 

### Server keys

Right now the keys attribute in the nfs_servers is an empty array. If you want to make use of any keys you can hardcode a keyid in the keys-array. I didn't spent time on this for now because we'll use the ansible generated keys that will be created at automation-time.

### Additional Files 
For Development I added a file to my /scrap folder called **provider.auto.tfvars.j2** that looked like this:

```
# apikey for your account. 
ibmcloud_api_key = "YourApiKey"

```
The initial idea was to inject the api_key via this template to the terraform-workdir. I the end I hardcoded it in ths file because we already have a solution for this.  

The playbook **playbook-sample-run-generators.yaml** now copies this file to the terraform-workdir (Line 60, commented out for now) after the generators have been run. We could do the same with the generated public-keys.

The generator for the nfs_server could check if the definition for the key exists (the `resource "ibm_is_ssh_key" "provision_ssh"`-file that Frank posted in Slack) and if it is there already - could add an reference (`ibm_is_ssh_key.provision_ssh.id`) to the **keys=[]** section of the nfs_servers template. This is planned for friday.