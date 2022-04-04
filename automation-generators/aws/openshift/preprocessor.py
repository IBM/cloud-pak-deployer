from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: sample
#   ocp_version: 4.8.24
#   compute_flavour: m5.4xlarge
#   compute_nodes: 3
#   infrastructure:
#     type: rosa
#     aws_region: eu-central-1
#     multi_zone: True
#     use_sts: False
    # machine-cidr: 10.243.0.24
    # subnet_idss:
    # - subnet-0e63f662bb1842e8a
    # - subnet-0673351cd49877269
    # - subnet-00b007a7c2677cdbc
    # - subnet-02b676f92c83f4422
    # - subnet-0f1b03a02973508ed
    # - subnet-027ca7cc695ce8515
#   openshift_storage:
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 500

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('name').isRequired()
    g('ocp_version').isRequired()
    g('compute_flavour').isRequired()
    g('compute_nodes').isRequired()
    
    g('infrastructure').isRequired()

    g('openshift_storage').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        # Check infrastructure attributes
        if "type" not in ge['infrastructure']:
            g.appendError(msg='type must be specified for infrastructure')
        elif ge['infrastructure']['type'] not in ['rosa']:
            g.appendError(msg='infrastructure.type must be rosa')
        if "aws_region" not in ge['infrastructure']:
            g.appendError(msg='aws_region must be specified for infrastructure')
        if "multi_zone" in ge['infrastructure']:
            if type(ge['infrastructure']['multi_zone']) != bool:
                g.appendError(msg='multi_zone must be True or False if specified')
        if "use_sts" in ge['infrastructure']:
            if type(ge['infrastructure']['use_sts']) != bool:
                g.appendError(msg='use_sts must be True or False if specified')
        if "machine_cidr" in ge['infrastructure']:
            if "subnet_ids" not in ge['infrastructure']:
                g.appendError(msg='If machine_cidr is specified, you must also specify the subnet_ids attribute')
        if "subnet_ids" in ge['infrastructure']:
            if len(ge['infrastructure']['subnet_ids']) != 2 and len(ge['infrastructure']['subnet_ids']) != 6:
                g.appendError(msg='You can specify either 2 subnet IDs or 6 subnet IDs if there are existing subnets in the VPC')
            if "machine_cidr" not in ge['infrastructure']:
                g.appendError(msg='If subnet IDs are specified, you must also specify the machine_cidr attribute')

        # Check upstream DNS server
        if 'upstream_dns' in ge:
            for dns in ge['upstream_dns']:
                if 'name' not in dns:
                    g.appendError(msg='name must be specified for all upstream_dns elements')
                if 'zones' not in dns:
                    g.appendError(msg='zones must be specified for all upstream_dns elements')
                elif len(dns['zones']) < 1:
                    g.appendError(msg='At least 1 zones element must be specified for all upstream_dns configurations')
                if 'dns_servers' not in dns:
                    g.appendError(msg='dns_servers must be specified for all upstream_dns elements')
                elif len(dns['dns_servers']) < 1:
                    g.appendError(msg='At least 1 dns_servers element must be specified for all upstream_dns configurations')

        # Check openshift_storage atttributes
        if len(ge['openshift_storage']) < 1:
            g.appendError(msg='At least one openshift_storage element must be specified.')
        for os in ge['openshift_storage']:
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            if "storage_type" in os and os['storage_type'] not in ['ocs']:
                g.appendError(msg='storage_type must be ocs')
            if "storage_type" in os and os['storage_type']=='ocs':
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified when storage_type is ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified when storage_type is ocs')
                if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                    g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


