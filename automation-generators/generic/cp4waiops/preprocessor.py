from generatorPreProcessor import GeneratorPreProcessor
import sys, os
import re

# Reference
# ---

# openshift:
# - name: sample
#   ...
#   openshift_storage:
#   - storage_name: auto-storage
#     storage_type: auto

# Validating:
# ---

# ---
# cp4waiops:

# - project: cp4i
#   openshift_cluster_name: "{{ env_id }}"
#   openshift_storage_name: auto-storage
#   accept_licenses: False
 
#   instances:
#   - name: cp4waiops-aimanager-navigator
#     kind: AIManager
#     install: true

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
    openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
    g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')
    g('instances').isRequired()
    g('accept_licenses').isOptional().mustBeOneOf([True, False])

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # Check for cp4waiops:     

        # If air-gapped install, image registry name must be specified
        if str_to_bool(os.environ.get('CPD_AIRGAP')):
            if 'image_registry_name' not in ge:
                g.appendError(msg="When doing an air-gapped install, the image_registry_name must be specified for the cp4waiops object")

        # Check accept_licenses property
        if 'accept_licenses' in ge:
            accept_licenses=ge['accept_licenses']
        else:
            accept_licenses=False
        # Check if licenses were accepted if cluster must not be destroyed
        # if os.environ.get('ACTION') != 'destroy':
        #     if not accept_licenses:
        #         if not str_to_bool(os.environ.get('CPD_ACCEPT_LICENSES')):
        #             g.appendError(msg="You must accept licenses by specifying accept_licenses: True or by using the --accept-all-licenses command line flag")

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
                    # now check if it has a openshift_storage with the name cp4waiops.openshift_storage_name

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


        # Iterate over all instances to check if name and kind attributes is given. If not throw an error
        for c in ge['instances']:
            if "name" not in c:
                g.appendError(msg='name must be specified for all instances elements')
            if "kind" not in c:
                g.appendError(msg='kind must be specified for all instances elements')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result