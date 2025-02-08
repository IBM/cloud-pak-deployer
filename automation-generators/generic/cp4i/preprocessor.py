from generatorPreProcessor import GeneratorPreProcessor
import sys, os
import re

# Reference
# ---

# openshift:
# - name: sample
#   ocp_version: 4.6
#   compute_flavour: bx2.16x64
#   compute_nodes: 3
#   resource_group_name: ibm
#   infrastructure:
#     type: vpc
#     vpc_name: "{{ env_id }}"
#     subnets: 
#     - "{{ env_id }}-subnet-zone-1"
#     - "{{ env_id }}-subnet-zone-2"
#     - "{{ env_id }}-subnet-zone-3"
#   openshift_storage:
#   - storage_name: odf-storage
#     storage_type: odf
#     odf_storage_label: ocs
#     odf_storage_size_gb: 500

# Validating:
# ---

# ---
# cp4i:

# - project: cp4i
#   openshift_cluster_name: "{{ env_id }}"
#   openshift_storage_name: odf-storage
#   cp4i_version: 2021.4.1
#   use_case_files: True
#   accept_licenses: False
#   use_top_level_operator: False
#   top_level_operator_channel: v1.5
#   top_level_operator_case_version: 2.5.0
#   operators_in_all_namespaces: True
 
#   instances:

#   - name: integration-navigator
#     type: platform-navigator
#     license: L-RJON-C7QG3S
#     channel: v5.2
#     case_version: 1.5.0

def str_to_bool(s):
    if s == None:
        return False
    else:
        return s.lower() in ['true','yes','1']

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    global g
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('project').isRequired()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('cp4i_version').isRequired()
    g('instances').isRequired()
    g('use_case_files').isOptional().mustBeOneOf([True, False])
    g('olm_utils').isOptional().mustBeOneOf([True, False])
    g('accept_licenses').isOptional().mustBeOneOf([True, False])

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # Check for cp4i:
        openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
        g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')

        # Check that version matches x.y.z pattern
        if not re.match(r"[0-9]+\.[0-9]\.[0-9]+",str(ge['cp4i_version'])):
            g.appendError(msg="cp4i_version must be in the format of x.y.z, for example 2021.4.1")

        # If air-gapped install, image registry name must be specified
        if str_to_bool(os.environ.get('CPD_AIRGAP')):
            if 'image_registry_name' not in ge:
                g.appendError(msg="When doing an air-gapped install, the image_registry_name must be specified for the cp4i object")

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

# Check reference
# - Retrieve the openshift element with name=openshift_cluster_name
# - Within the openshift element retrieve, there must be an openshift_storage element with the name cp4d.openshift_storage_name
        openshift_names = []
        if 'openshift' in fc:
            openshift_names = fc.match('openshift[*].name')

            if 'openshift_cluster_name' in ge:
                if ge['openshift_cluster_name'] not in openshift_names:
                    g.appendError(msg="Was not able to find an OpenShift cluster with name: "+ge['openshift_cluster_name'])
                else:
                    # we made sure the cluster referenced by openshift_cluster_name exists
                    # now check if it has a openshift_storage with the name cp4d.openshift_storage_name

                    # to make use of benedict .find() we'll need list indexes
                    # therefore we'll loop over the list indexes and not over the contained objects/entries
                    for cluster_index in range(len(fc['openshift'])):
                        # iterate over the openshift clusters
                        # until we are at the cluster with the name
                        # referenced in ge['openshift_cluster_name']
                        if fc['openshift'][cluster_index].get('name',None) == ge['openshift_cluster_name']:
                            # check if the cluster referenced by ge['openshift_cluster_name'] has a 'openshift_storage'
                            # attribute defined
                            if 'openshift_storage' not in fc['openshift['+str(cluster_index)+']']:
                                g.appendError(msg="The cluster '"+ ge['openshift_cluster_name'] +"' has no attribute openshift_storage")
                            else:
                                # receive the names of the entries inside the clusters openshift_storage-list
                                remote_storage_names = []
                                remote_storage_names = fc.match('openshift['+str(cluster_index)+'].openshift_storage[*].storage_name')
                                if 'openshift_storage_name' in ge:
                                    if ge['openshift_storage_name'] not in remote_storage_names:
                                        g.appendError(msg="The cluster with name "+ ge['openshift_cluster_name'] +" doesn't have a openshift_storage element with name "+ge['openshift_storage_name'] +"")


        # Iterate over all instances to check if name and type attributes is given. If not throw an error
        for c in ge['instances']:
            if "type" not in c:
                g.appendError(msg='type must be specified for all instances elements')
            if "state" in c:
                if c['state'] not in ['installed','removed']:
                    g.appendError(msg='Instance state must be "installed" or "removed"')

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
