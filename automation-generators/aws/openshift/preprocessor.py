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
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 500

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

        # Check openshift_storage atttributes
        if len(ge['openshift_storage']) < 1:
            g.appendError(msg='At least one openshift_storage element must be specified.')
        for os in ge['openshift_storage']:
            if "storage_name" not in os:
                g.appendError(msg='storage_name must be specified for all openshift_storage elements')
            if "storage_type" not in os:
                g.appendError(msg='storage_type must be specified for all openshift_storage elements')
            if "storage_type" in os and os['storage_type'] not in ['ocs','aws-elastic']:
                g.appendError(msg='storage_type must be ocs or aws-elastic')
            if "storage_type" in os and os['storage_type']=='ocs':
                if "credentials_mode" in ge['infrastructure']:
                    g.appendError(msg='Installation of ODF using temporary cloud credentials (credentials_mode property) is not supported. Please choose elastic storage or install using permanent credentials.')
                if "ocs_storage_label" not in os:
                    g.appendError(msg='ocs_storage_label must be specified when storage_type is ocs')
                if "ocs_storage_size_gb" not in os:
                    g.appendError(msg='ocs_storage_size_gb must be specified when storage_type is ocs')
                if "ocs_version" in os and version.parse(str(os['ocs_version'])) < version.parse("4.6"):
                    g.appendError(msg='ocs_version must be 4.6 or higher. If the OCS version is 4.10, specify ocs_version: "4.10"')

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


