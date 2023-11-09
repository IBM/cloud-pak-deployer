from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: sample
#   ocp_version: 4.6
#   compute_flavour: bx2.16x64
#   compute_nodes: 3
#   infrastructure:
#     type: vpc
#     vpc_name: sample
#     subnets: 
#     - sample-subnet-zone-1
#     - sample-subnet-zone-2
#     - sample-subnet-zone-3
#   cloud_native_toolkit: False
#   upstream_dns:
#   - name: sample-dns
#     zones:
#     - sample.com
#     dns_servers:
#     - 172.31.2.73:53
#   openshift_storage:
#   - storage_name: vpc-storage
#     storage_type: ibm-vpc-storage
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 500

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    #Level 1
    g('name').isRequired()
    g('managed').isOptional().mustBeOneOf([True,False])
    g('ocp_version').isRequired()
    g('compute_flavour').isRequired()
    g('compute_nodes').isRequired()    
    g('infrastructure').isRequired()
    g('openshift_storage').isRequired()
    #Level 2
    if len(g.getErrors()) == 0:
        g('infrastructure.type').mustBeOneOf(['vpc'])
        g('infrastructure.vpc_name').expandWith('vpc[*]',remoteIdentifier='name')
        g('infrastructure.subnets').isRequired()
        g('infrastructure.cos_name').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')

        # Number of subnets must be 1 or 3
        if len(ge['infrastructure']['subnets']) != 1 and len(ge['infrastructure']['subnets']) != 3:
            g.appendError(msg='Number of subnets specified is ' + str(len(ge['infrastructure']['subnets'])) + ' must be 1 or 3')

        # Number of compute nodes must be a factor of the number of subnets
        if (ge['compute_nodes'] % len(ge['infrastructure']['subnets'])) != 0:
            g.appendError(msg='compute_nodes must be a factor of the number of subnets')

        # private_only must be true or false if specified
        if 'private_only' in ge['infrastructure']:
            if type(ge['infrastructure']['private_only']) != bool:
                g.appendError(msg='Attribute infrastructure.private_only must be either true or false if specified. Default is false.')

        # check deny_node_ports must be true or false if specified
        if 'deny_node_ports' in ge['infrastructure']:
            if type(ge['infrastructure']['deny_node_ports']) != bool:
                g.appendError(msg='Attribute infrastructure.deny_node_ports must be either true or false if specified. Default is false.')

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
            if "storage_type" in os and os['storage_type'] not in ['ibm-vpc-storage','ocs','pwx']:
                g.appendError(msg='storage_type must be ibm-vpc-storage, ocs or pwx')
            if "storage_type" in os and os['storage_type']=='ocs':
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified when storage_type is ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified when storage_type is ocs')
                    g.appendError(msg='Storage type OCS was specified but there are not 3 subnets for the cluster. You must have 3 subnets for the OpenShift cluster to implement OCS.')
                if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                    g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')

            if "storage_type" in os and os['storage_type']=='pwx':
                if "pwx_etcd_location" not in os:
                    g.appendError(msg='pwx_etcd_location must be specified when storage_type is pwx')
                if "pwx_storage_size_gb" not in os:
                    g.appendError(msg='pwx_storage_size_gb must be specified when storage_type is pwx')
                if "pwx_storage_iops" not in os:
                    g.appendError(msg='pwx_storage_iops must be specified when storage_type is pwx')
                if "pwx_storage_profile" not in os:
                    g.appendError(msg='pwx_storage_profile must be specified when storage_type is pwx')
                if "portworx_version" not in os:
                    g.appendError(msg='portworx_version must be specified when storage_type is pwx')
                if "stork_version" not in os:
                    g.appendError(msg='stork_version must be specified when storage_type is pwx')
                if len(ge['infrastructure']['subnets']) != 3:
                    g.appendError(msg='Storage type PWX was specified but there are not 3 subnets for the cluster. You must have 3 subnets for the OpenShift cluster to implement PWX.')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


