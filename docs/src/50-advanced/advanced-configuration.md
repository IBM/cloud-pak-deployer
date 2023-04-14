# Cloud Pak Deployer Advanced Configuration

## Using dynamic variables (extra variables)
In some situations you may want to use a single configuration for deployment in different environments, such as development, acceptance test and production. The Cloud Pak Deployer uses the Jinja2 templating engine which is included in Ansible to pre-process the configuration. This allows you to dynamically adjust the configuration based on extra variables you specify at the command line.

Example:
```
./cp-deploy.sh env apply \
  -e ibm_cloud_region=eu_gb \
  -e env_id=jupiter-03 [--accept-all-liceneses]
```

This passes the `env_id` and `ibm_cloud_region` variables to the Cloud Pak Deployer, which can then populate variables in the configuration. In the sample configurations, the `env_id` is used to specify the name of the VPC, ROKS cluster and others and overrides the value specified in the `global_config` definition. The `ibm_cloud_region` overrides region specified in the inventory file.

```
...
vpc:
- name: "{{ env_id }}"
  allow_inbound: ['ssh']

address_prefix:
### Prefixes for the client environment
- name: "{{ env_id }}-zone-1"
  vpc: "{{ env_id }}"
  zone: {{ ibm_cloud_region }}-1
  cidr: 10.231.0.0/26
...
```

When running with the above `cp-deploy.sh` command, the snippet would be generated as:
```
...
vpc:
- name: "jupiter-03"
  allow_inbound: ['ssh']

address_prefix:
### Prefixes for the client environment
- name: "jupiter-03-zone-1"
  vpc: "jupiter-03"
  zone: eu-de-1
  cidr: 10.231.0.0/26
...
```

The `ibm_cloud_region` variable is specified in the inventory file. This is another method of specifying variables for dynamic configuration.

You can even include more complex constructs for dynamic configuration, with `if` statements, `for` loops and others.

An example where the OpenShift OCS storage classes would only be generated for a specific environment (pluto-prod) would be:
```
  openshift_storage:
  - storage_name: nfs-storage
    storage_type: nfs
    nfs_server_name: "{{ env_id }}-nfs"
{% if env_id == 'jupiter-prod' %}
  - storage_name: ocs-storage
    storage_type: ocs
    ocs_storage_label: ocs
    ocs_storage_size_gb: 500
{% endif %}
```

For a more comprehensive overview of Jinja2 templating, see https://docs.ansible.com/ansible/latest/user_guide/playbooks_templating.html