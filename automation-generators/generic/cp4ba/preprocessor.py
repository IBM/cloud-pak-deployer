from generatorPreProcessor import GeneratorPreProcessor
import sys, os
import re

# Reference
# ---

# openshift:
# - name: sample
#   ocp_version: 4.6
# ...
#   openshift_storage:
#   - storage_name: nfs-storage
#     storage_type: nfs
#     nfs_server_name: "{{ env_id }}-nfs"

# Validating:
# ---

#cp4ba:
#- project: cp4ba
#  openshift_cluster_name: sample
#  openshift_storage_name: nfs-storage
#  accept_licenses: False

#  cartridges:

def str_to_bool(s):
    if s == None:
        return False
    else:
        return s.lower() in ['true','yes','1']

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    global g
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('project').isRequired()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
    g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')
    g('accept_licenses').isOptional().mustBeOneOf([True, False])
    g('state').isRequired().mustBeOneOf(['installed', 'removed'])
    g('cloudbeaver_enabled').isOptional().mustBeOneOf([True, False])
    g('roundcube_enabled').isOptional().mustBeOneOf([True, False])
    g('cerebro_enabled').isOptional().mustBeOneOf([True, False])
    g('akhq_enabled').isOptional().mustBeOneOf([True, False])

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # Check accept_licenses property
        if 'accept_licenses' in ge:
            accept_licenses=ge['accept_licenses']
        else:
            accept_licenses=False
        # Check if licenses were accepted if cluster must not be destroyed
        if os.environ.get('ACTION') != 'destroy':
            if not accept_licenses:
                if not str_to_bool(os.environ.get('CPD_ACCEPT_LICENSES')):
                    g.appendError(msg="You must accept licenses by specifying accept_licenses: True or by using the --accept-all-licenses command line flag")


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result

def check_cp_foundation(c):
    if "license_service" in c:
        license_service=c['license_service']
        if "state" in license_service:
            if license_service['state'] not in ['enabled','disabled']:
                g.appendError(msg='License service state (license_service.state) must be enabled or disabled')
        if "threads_per_core" in license_service:
            if not isinstance(license_service['threads_per_core'],int):
                g.appendError(msg='Number of threads per core (license_service.threads_per_core) must be numeric')
