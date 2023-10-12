from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: fk-cpd
#   domain_name: coc.ibm.com
#   cluster_name: fk-cpd
#   vsphere_name: fk-cpd
#   ocp_version: "4.10"
#   control_plane_nodes: 3
#   control_plane_vm_definition: control-plane
#   compute_nodes: 3
#   compute_vm_definition: compute
#   api_vip: 10.99.92.51
#   ingress_vip: 10.99.92.52
#   cloud_native_toolkit: False
#   openshift_storage:
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_version: 4.9
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 512
#     ocs_dynamic_storage_class: thin
#     storage_vm_definition: storage

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('ocp_version').isRequired()
    
    g('domain_name').isRequired()

    g('vsphere_name').expandWith('vsphere[*]',remoteIdentifier='name')

    g('control_plane_nodes').isRequired()
    g('control_plane_vm_definition').isRequired()
    g('compute_nodes').isRequired()
    g('compute_vm_definition').isRequired()

    g('api_vip').isRequired()
    g('ingress_vip').isRequired()


    g('openshift_storage').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')

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

        if 'mcg' in ge:
            mcg=ge['mcg']
            if 'install' not in mcg:
                g.appendError(msg='install property must be specified in openshift.mcg')
            elif type(mcg['install']) != bool:
                g.appendError(msg='Value mcg.install must be True or False')
            if 'storage_type' not in mcg:
                g.appendError(msg='storage_type property must be specified in openshift.mcg')
            elif mcg['storage_type'] not in ['storage-class']:
                g.appendError(msg='Value mcg.storage_type must be storage-class')
            if 'storage_class' not in mcg:
                g.appendError(msg='storage_class property must be specified in openshift.mcg')
                
        # Check openshift_storage atttributes
        if len(ge['openshift_storage']) < 1:
            g.appendError(msg='At least one openshift_storage element must be specified.')
        for os in ge['openshift_storage']:
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            if "storage_type" in os and os['storage_type'] not in ['nfs','ocs']:
                g.appendError(msg='storage_type must be nfs or ocs')
            if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')
            #for ocs
            if "storage_type" in os and os['storage_type'] == 'ocs':
                if "storage_vm_definition" not in os:
                    g.appendError(msg='storage_vm_definition must be specified for openshift_storage elements of storage_type ocs')
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified for openshift_storage elements of storage_type ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified for openshift_storage elements of storage_type ocs')
                if "ocs_dynamic_storage_class" not in os:
                    g.appendError(msg='ocs_dynamic_storage_class must be specified for openshift_storage elements of storage_type ocs')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


