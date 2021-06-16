# Generators Role

The sample playbook is **playbook-sample-run-generators.yaml**. It will make use of the folders: 

* sample-generators/environment_definitions
* sample-generators/generator_config

The first one contains definitions. One file contains exact one environment definition. No multifile support, yet.

The second one contains all the generators. They are triggered like roles. The toplevel-key in the **sample-generators/environment_definitions/sample.yaml** map to the names of the generators, contained in **sample-generators/generator_config/generators**. The generators-role in **automation-roles/preprocess/generators** will just iterate over the elements contained under each toplevel-key inside the **sample.yaml** and pass the defined attributes to the main.yaml of each generator. From there on the generators behave like simple task-collections. 