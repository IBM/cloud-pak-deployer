from generatorPreProcessor import GeneratorPreProcessor
from packaging import version

# Validating:
# ---
# openshift:
# - name: sample
#   ocp_version: 4.10.34
#   compute_flavour: m5.4xlarge
#   compute_nodes: 3
#   infrastructure:
#     type: rosa
#     aws_region: eu-central-1
#     multi_zone: True
#     use_sts: False
#     credentials_mode: Manual
    # control_plane_iam_role: OpenShift-control-plane-role
    # compute_iam_role: OpenShift-compute-role
    # machine-cidr: 10.243.0.24
    # subnet_idss:
    # - subnet-0e63f662bb1842e8a
    # - subnet-0673351cd49877269
    # - subnet-00b007a7c2677cdbc
    # - subnet-02b676f92c83f4422
    # - subnet-0f1b03a02973508ed
    # - subnet-027ca7cc695ce8515
#   cloud_native_toolkit: False
#   openshift_storage:
#   - storage_name: odf-storage
#     storage_type: odf
#     odf_storage_label: ocs
#     odf_storage_size_gb: 500

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    
    #Check Must Fields
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
        var=g.getModuleVariables()

        # OpenShift version must be 4.6 or higher
        if version.parse(str(ge['ocp_version'])) < version.parse("4.6"):
            g.appendError(msg='ocp_version must be 4.6 or higher. If the OpenShift version is 4.10, specify ocp_version: "4.10"')

        if 'cloud_native_toolkit' in ge:
            if type(ge['cloud_native_toolkit']) != bool:
                g.appendError(msg='Attribute cloud_native_toolkit must be either true or false if specified. Default is false.')

        # Check infrastructure attributes
        if "type" not in ge['infrastructure']:
            g.appendError(msg='type must be specified for infrastructure')
        elif ge['infrastructure']['type'] not in ['rosa','self-managed']:
            g.appendError(msg='infrastructure.type must be rosa or self-managed')
        if "aws_region" not in ge['infrastructure']:
            g.appendError(msg='aws_region must be specified for infrastructure')
        if "multi_zone" in ge['infrastructure']:
            if type(ge['infrastructure']['multi_zone']) != bool:
                g.appendError(msg='multi_zone must be True or False if specified')
        if "use_sts" in ge['infrastructure']:
            if type(ge['infrastructure']['use_sts']) != bool:
                g.appendError(msg='use_sts must be True or False if specified')
        if "credentials_mode" in ge['infrastructure']:
            if ge['infrastructure']['credentials_mode'] not in ['Manual','Mint']:
                g.appendError(msg='credentials_mode must be Manual or Mint if specified')
        
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
        for i, os in enumerate(ge['openshift_storage']):
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            else:
                if os['storage_type']=='ocs':
                    os.update([("storage_type", "odf")])                
                if os['storage_type'] not in ['odf','aws-elastic']:
                    g.appendError(msg='storage_type must be odf or aws-elastic')
                if os['storage_type']=='aws-elastic':
                    nfs_server_names = []
                    if 'nfs_server' in fc:
                        nfs_server_names = fc.match('nfs_server[*].name')
                    if "storage_name" not in os:
                        g.appendError(msg='storage_name must be specified when storage_type is aws-elastic')
                    elif os['storage_name'] not in nfs_server_names:
                        g.appendError(msg="'"+ os['storage_name'] + "' is not an existing nfs_server name (Found nfs_server: ["+ ','.join(nfs_server_names) +"] )")
                if os['storage_type']=='odf':
                    if "ocs_storage_label" in os:
                        os.update([("odf_storage_label", os['ocs_storage_label'])])
                    if "ocs_storage_size_gb" in os:
                        os.update([("odf_storage_size_gb", os['ocs_storage_size_gb'])])
                    if "ocs_version" in os:
                        os.update([("odf_version", os['ocs_version'])])
                    if "odf_storage_label" not in os:
                        g.appendError(msg='odf_storage_label must be specified when storage_type is odf')
                    if "odf_storage_size_gb" not in os:
                        g.appendError(msg='odf_storage_size_gb must be specified when storage_type is odf')
                    if "odf_version" in os and version.parse(str(os['odf_version'])) < version.parse("4.6"):
                        g.appendError(msg='odf_version must be 4.6 or higher. If the ODF version is 4.10, specify odf_version: "4.10"')

            # Ensure the openshift_storage attribute is updated
            ge['openshift_storage'][i]=os
            g.setExpandedAttributes(ge)                    

        #check variables for aws   
        if '_aws_access_key' in var and var['_aws_access_key'] == "":
            g.appendError(msg='Secret aws-access-key is not found or it is empty in the vault')
        if '_aws_secret_access_key' in var and var['_aws_secret_access_key'] == "":
            g.appendError(msg='Secret aws-secret-access-key is not found or it is empty in the vault')

        #check configuration and variables for self-managed aws
        if "type" in ge['infrastructure'] and ge['infrastructure']['type'] in ['self-managed']:
            g('domain_name').isRequired()

            if '_ocp_pullsecret' in var and var['_ocp_pullsecret'] == "":
                g.appendError(msg='Secret ocp-pullsecret is not found or it is empty in the vault')
            if '_ocp_ssh_pub_key' in var and var['_ocp_ssh_pub_key'] == "":
                g.appendError(msg='Secret ocp-ssh-pub-key is not found or it is empty in the vault')

        #check configuration and variables for rosa aws
        if "type" in ge['infrastructure'] and ge['infrastructure']['type'] in ['rosa']:  
            if var['_rosa_login_token'] == "":
                g.appendError(msg='Secret rosa-login-token is not found or it is empty in the vault')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


