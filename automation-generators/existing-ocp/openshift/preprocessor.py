from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: {{ env_id }}
#   ocp_version: 4.8
#   cloud_native_toolkit: False
#   openshift_storage:
#   - storage_name: nfs-storage
#     storage_type: nfs
# Optional parameters if you want to override the storage class used
#     ocp_storage_class_file: nfs-client 
#     ocp_storage_class_block: nfs-client

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    # Initialize GeneratorPreProcessor
    g = GeneratorPreProcessor(attributes, fullConfig, moduleVariables)

    # Ensure required attributes are present
    g('name').isRequired()
    g('ocp_version').isRequired()    
    g('openshift_storage').isRequired()

    # Validate attribute details if previous checks pass
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge = g.getExpandedAttributes()

        # Validate OpenShift version
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        # Validate cloud_native_toolkit attribute
        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')
       
        # Validate infrastructure attributes
        if 'infrastructure' in ge:
            if 'type' in ge['infrastructure']:
                if ge['infrastructure']['type'] not in ['ibm-roks','aws-self-managed','aws-rosa','azure-aro','vsphere','standard','detect']:
                    g.appendError(msg='infrastructure.type must be ibm-roks, aws-self-managed, aws-rosa, azure-aro, vsphere, standard, or detect')
            if 'processor_architecture' in ge['infrastructure']:
                if ge['infrastructure']['processor_architecture'] not in ['amd64','ppc64le','s390x']:
                    g.appendError(msg='infrastructure.processor_architecture must be amd64, ppc64le, or s390x')

        # Validate upstream DNS server
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

        # Validate mcg attributes
        if 'mcg' in ge:
            mcg = ge['mcg']
            if 'install' not in mcg:
                g.appendError(msg='install property must be specified in openshift.mcg')
            elif type(mcg['install']) != bool:
                g.appendError(msg='Value mcg.install must be True or False')
            if 'storage_type' not in mcg:
                g.appendError(msg='storage_type property must be specified in openshift.mcg')
            elif mcg['storage_type'] != 'storage-class':
                g.appendError(msg='Value mcg.storage_type must be storage-class')
            if 'storage_class' not in mcg:
                g.appendError(msg='storage_class property must be specified in openshift.mcg')
                
      # Validate openshift_storage attributes
        if len(ge['openshift_storage']) < 1:
            g.appendError(msg='At least one openshift_storage element must be specified.')
        for os in ge['openshift_storage']:
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            if "storage_type" in os and os['storage_type'] not in ['nfs','ocs','aws-elastic','pwx','ibm-storage','custom','auto']:
                g.appendError(msg='storage_type must be nfs, ocs, aws-elastic, ibm-storage, custom, or auto')
            if "storage_type" in os and os['storage_type'] == 'custom':
                if "ocp_storage_class_file" not in os:
                    g.appendError(msg='ocp_storage_class_file must be specified when storage_type is custom')
                if "ocp_storage_class_block" not in os:
                    g.appendError(msg='ocp_storage_class_block must be specified when storage_type is custom')
                    
    # Return result containing updated attributes and errors
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result