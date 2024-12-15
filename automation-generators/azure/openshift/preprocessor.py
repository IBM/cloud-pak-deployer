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
#   compute_disk_size_gb: 300
#   compute_nodes: 3
#   network:
#     pod_cidr: "10.128.0.0/14"
#     service_cidr: "172.30.0.0/16"
#     machine_cidr: 
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
    g('domain_name').isRequired()
    g('azure_name').expandWith('azure[*]',remoteIdentifier='name')
    g('control_plane_flavour').isRequired()
    g('compute_flavour').isRequired()
    g('compute_disk_size_gb').isRequired()
    g('compute_nodes').isRequired()
    g('ocp_version').isRequired()
    g('openshift_storage').isRequired()

    g('network.machine_cidr').isRequired()
    g('network.pod_cidr').isRequired()
    g('network.service_cidr').isRequired()
    g('infrastructure.type').isRequired().mustBeOneOf(['self-managed','aro'])
    g('infrastructure.multi_zone').isRequired()
    g('infrastructure.private_only').isRequired()


    # Get azure configuration
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()
        azure={}
        for a in fullConfig['azure']:
            if a['name']==ge['azure_name']:
                azure=a
        if azure=={}:
            g.appendError(msg='azure resource {} not found'.format(ge['azure_name']))

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        # If type is self-managed, the domain name is required
        if ge['infrastructure']['type'] == 'self-managed':
            g('domain_name').isRequired()

        if type(ge['infrastructure']['multi_zone']) != bool:
                g.appendError(msg='Attribute multi_zone must be either true or false.')
        if type(ge['infrastructure']['private_only']) != bool:
                g.appendError(msg='Attribute private_only must be either true or false.')

        # Domain resource group is mandatory for public OpenShift
        if ge['infrastructure']['private_only'] == False:
                g('domain_resource_group').isRequired()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')

        # Validate gpu attributes
        if 'gpu' in ge:
            gpu = ge['gpu']
            if 'install' not in gpu:
                g.appendError(msg='install property must be specified in openshift.gpu')
            elif str(gpu['install']).lower() not in ['true','false','auto']:
                g.appendError(msg='Value gpu.install must be True, False or auto')

        # Validate openshift_ai attributes
        if 'openshift_ai' in ge:
            openshift_ai = ge['openshift_ai']
            if 'install' not in openshift_ai:
                g.appendError(msg='install property must be specified in openshift.openshift_ai')
            elif str(openshift_ai['install']).lower() not in ['true','false','auto']:
                g.appendError(msg='Value openshift_ai.install must be True, False or auto')

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
            if "storage_type" in os and os['storage_type'] not in ['ocs','nfs']:
                g.appendError(msg='storage_type must be ocs or nfs')
            if "storage_type" in os and os['storage_type']=='ocs':
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified when storage_type is ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified when storage_type is ocs')
                if "ocs_dynamic_storage_class" not in os:
                    g.appendError(msg='ocs_dynamic_storage_class must be specified when storage_type is ocs')
                if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                    g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')

    # Check azure configuration
    if len(g.getErrors()) == 0:
        ga = GeneratorPreProcessor(azure,fullConfig,moduleVariables)

        ga('name').isRequired()
        ga('sp_name').isRequired()
        ga('resource_group.name').isRequired()
        ga('resource_group.location').isRequired()    

        if ge['infrastructure']['type'] == 'aro':
            ga('vnet.name').isRequired()
            ga('vnet.address_space').isRequired()
            ga('control_plane.subnet.name').isRequired()
            ga('control_plane.subnet.address_prefixes').isRequired()
            ga('compute.subnet.name').isRequired()
            ga('compute.subnet.address_prefixes').isRequired()

        if ge['infrastructure']['private_only'] == True:
            ga('vnet.name').isRequired()
            ga('vnet.network_resource_group_name').isRequired()
            ga('control_plane.subnet.name').isRequired()
            ga('compute.subnet.name').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


