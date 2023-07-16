from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
#---
# openshift:
# - name: "{{ env_id }}-cluster"
#   azure_name: "{{ env_id }}-infra"
#   domain_name: deployer.eu
#   ocp_version: 4.12
#   control_plane_flavour: Standard_D8s_v3
#   compute_flavour: Standard_D16s_v3
#   compute_disk_size_gb: 128
#   compute_nodes: 3
#   network:
#     pod_cidr: "10.128.0.0/14"
#     service_cidr: "172.30.0.0/16"
#   openshift_storage:
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 512
#     ocs_dynamic_storage_class: managed-premium

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    
    #Check Must Fields
    #Level 1
    g('name').isRequired()
    g('azure_name').isRequired()    
    g('domain_name').isOptional()
    g('control_plane_flavour').isRequired()
    g('compute_flavour').isRequired()
    g('compute_disk_size_gb').isRequired()
    g('compute_nodes').isRequired()
    g('ocp_version').isRequired()
    g('network').isRequired()
    g('openshift_storage').isRequired()

    #Level 2
    if len(g.getErrors()) == 0:
        g('network.pod_cidr').isRequired()
        g('network.service_cidr').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')

        # Check openshift_storage atttributes
        if len(ge['openshift_storage']) < 1:
            g.appendError(msg='At least one openshift_storage element must be specified.')
        for os in ge['openshift_storage']:
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            if "storage_type" in os and os['storage_type'] not in ['ocs','nfs']:
                g.appendError(msg='storage_type must be ocs or nfs')
            if "storage_type" in os and os['storage_type']=='ocs':
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified when storage_type is ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified when storage_type is ocs')
                if "ocs_dynamic_storage_class" not in os:
                    g.appendError(msg='ocs_dynamic_storage_class must be specified when storage_type is ocs')
                else:
                    if os['ocs_dynamic_storage_class'] not in ['managed-premium']:
                        g.appendError(msg='ocs_dynamic_storage_class must be managed-premium')
                if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                    g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


