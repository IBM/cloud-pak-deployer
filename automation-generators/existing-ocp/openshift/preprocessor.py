from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: {{ env_id }}
#   ocp_version: 4.8
#   cluster_name: {{ env_id }}
#   domain_name: example.com
#   openshift_storage:
#   - storage_name: nfs-storage
#     storage_type: nfs
# Optional parameters if you want to override the storage class used
#     ocp_storage_class_file: nfs-client 
#     ocp_storage_class_block: nfs-client

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('name').isRequired()
    g('ocp_version').isRequired()
    
    g('cluster_name').isRequired()
    g('domain_name').isRequired()

    g('openshift_storage').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

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
            if "storage_type" in os and os['storage_type'] not in ['nfs','ocs','aws-elastic','custom']:
                g.appendError(msg='storage_type must be nfs, ocs, aws-elastic or custom')
            if "storage_type" in os and os['storage_type']=='custom':
                if "ocp_storage_class_file" not in os:
                    g.appendError(msg='ocp_storage_class_file must be specified when storage_type is custom')
                if "ocp_storage_class_block" not in os:
                    g.appendError(msg='ocp_storage_class_block must be specified when storage_type is custom')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


