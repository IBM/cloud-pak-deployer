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
#   - storage_name: nfs-storage
#     storage_type: nfs
#     nfs_server_name: "{{ env_id }}-nfs"
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size_gb: 500

# Validating:
# ---

#cp4d:
#- project: cpd
#  openshift_cluster_name: sample
#  cp4d_version: 4.0.9
#  openshift_storage_name: nfs-storage
#  use_case_files: True
#  accept_licenses: False
#  sequential_install: False
#  change_node_settings: True

#  cartridges:
#  - name: cpfs
#    license_service:
#      state: disabled
#      threads_per_core: 2
#    case_version: 1.10.1
#  - name: cpd_platform
#    subscription_channel: v2.0
#    case_version: 2.0.8
#  - name: ws
#    version: 4.0.4
#    subscription_channel: v2.0
#    case_version: 2.0.4
#  - name: wml
#    version: 4.0.4
#    subscription_channel: v1.1
#    case_version: 4.0.5
#    size: small

#
# All tested cartridges. To install, uncomment the entry, make sure that the "-"" and properties
# are aligned with the other "cartridges" entries.
#

  # - name: analyticsengine 
  #   version: 4.0.4
  #   subscription_channel: stable-v1
  #   case_version: 4.0.4
  #   size: small 
  # - name: bigsql
  #   version: 7.2.3
  #   subscription_channel: v7.2
  #   case_version: 7.2.3
  # - name: cognos_analytics
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.6
  #   size: small
  #   instances:
  #   - name: ca-instance
  #     metastore_ref: ca-metastore
  # - name: cde
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 2.0.4
  # - name: datagate
  #   version: 2.0.4
  #   subscription_channel: v2.0
  #   case_version: 4.0.4
  # - name: datastage
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 4.0.5
  # - name: db2
  #   version: 4.0.6
  #   subscription_channel: v1.0
  #   case_version: 4.0.6
  #   size: small
  #   instances:
  #   - name: ca-metastore
  #     metadata_size_gb: 20
  #     data_size_gb: 20
  #     backup_size_gb: 20  
  #     transactionlog_size_gb: 20
  # - name: db2u
  #   version: 4.0.6
  #   subscription_channel: v1.1
  #   case_version: 4.0.6
  # - name: db2wh
  #   version: 4.0.6
  #   subscription_channel: v1.0
  #   case_version: 4.0.6
  # - name: dmc
  #   version: 4.0.3
  #   subscription_channel: v1.0
  #   case_version: 4.0.3
  # - name: dods
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.4
  #   size: small
  # - name: dp
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 4.0.4
  #   size: small
  # - name: dv
  #   version: 1.7.3
  #   subscription_channel: v1.7
  #   case_version: 1.7.3
  #   size: small 
  #   dependencies:
  #   - name: db2u
  #   instances:
  #   - name: data-virtualization
  # - name: hee
  #   version: 4.0.4
  #   size: small
  #   subscription_channel: v1.0
  #   case_version: 4.0.4
  # - name: mdm
  #   version: 1.1.167
  #   subscription_channel: v1.1
  #   case_version: 1.0.166
  #   size: small
  #   wkc_enabled: true
  # - name: openpages
  #   version: 8.204.1
  #   subscription_channel: v1.0
  #   case_version: 2.1.1+20211213.164652.82041218
  # - name: planning-analytics
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.40403
  # - name: rstudio
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 1.0.4
  #   size: small
  # - name: spss
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 1.0.4
  # - name: voice-gateway
  #   version: 1.0.7
  #   subscription_channel: v1.0
  #   case_version: 1.0.4
  #   replicas: 1  
  # - name: watson_assistant
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.4
  #   size: small
  # - name: watson-discovery
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.4
  # - name: watson-ks
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.4
  #   size: small
  # - name: watson-openscale
  #   version: 4.0.4
  #   subscription_channel: v1
  #   case_version: 2.4.0
  #   size: small
  # - name: watson-speech
  #   version: 4.0.4
  #   subscription_channel: v4.0
  #   case_version: 4.0.4
  #   stt_size: xsmall
  #   tts_size: xsmall
  # - name: wkc
  #   version: 4.0.4
  #   subscription_channel: v1.0
  #   case_version: 4.0.4
  #   size: small
  # - name: wml
  #   version: 4.0.4
  #   subscription_channel: v1.1
  #   case_version: 4.0.5
  #   size: small
  # - name: wml-accelerator
  #   version: 2.3.4
  #   subscription_channel: v1.0
  #   case_version: 2.3.4
  #   replicas: 1
  #   size: small
  # - name: ws
  #   version: 4.0.4
  #   subscription_channel: v2.0
  #   case_version: 2.0.4

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
    g('cp4d_version').isRequired()
    g('cartridges').isRequired()
    g('use_case_files').isOptional().mustBeOneOf([True, False])
    g('sequential_install').isOptional().mustBeOneOf([True, False])
    g('accept_licenses').isOptional().mustBeOneOf([True, False])
    g('change_node_settings').isOptional()
    g('cp4d_entitlement').isOptional().mustBeOneOf(['cpd-enterprise', 'cpd-standard'])
    g('cp4d_production_license').isOptional().mustBeOneOf([True, False])

    # Expand storage if no errors yet
    if len(g.getErrors()) == 0:
        openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
        g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # Check for cp4d:     
        # Check that cpfs element exists
        # Check that cpd_platform element exists

        # Check that version matches x.y.z pattern
        if not re.match(r"[0-9]\.[0-9]\.[0-9]+",str(ge['cp4d_version'])):
            g.appendError(msg="cp4d_version must be in the format of x.y.z, for example 4.0.9")

        # If air-gapped install, image registry name must be specified
        if str_to_bool(os.environ.get('CPD_AIRGAP')):
            if 'image_registry_name' not in ge:
                g.appendError(msg="When doing an air-gapped install, the image_registry_name must be specified for the cp4d object")

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

        # Handle deprecated olm_utils property
        if 'olm_utils' in ge and not 'sequential_install' in ge:
            g('sequential_install').set(ge['olm_utils'])

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


        # Iterate over all cartridges to check if name-attribute is given. If not throw an error
        cpfsFound=False
        cpdPlatformFound=False
        listedCartridges=[]
        for c in ge['cartridges']:
            if "name" not in c:
                g.appendError(msg='name must be specified for all cartridges elements')
            else:
                if c['name'] in listedCartridges:
                    g.appendError(msg='Cartridge {} is listed more than once. You can only have 1 cartridge of each type in a project'.format(c['name']))
                else:
                    listedCartridges.append(c['name'])
                if c['name'] in ["cpd_platform","lite"]:
                    cpdPlatformFound=True
                if c['name'] in ["cpfs","cp-foundation"]:
                    cpfsFound=True
                    check_cp_foundation(c)
            if "state" in c:
                if c['state'] not in ['installed','removed']:
                    g.appendError(msg='Cartridge state must be "installed" or "removed"')
            if "state" not in c or c['state']=='installed':
                # Check if there are dependencies and the depencies will be installed too
                if "dependencies" in c:
                    for dep in c['dependencies']:
                        if 'name' not in dep:
                            g.appendError(msg='If dependencies are specifed, a name is required for every dependency')
                        else:
                            dep_found=False
                            for dc in ge['cartridges']:
                                if dc['name']==dep['name'] and ('state' not in dc or dc['state']=='installed'):
                                    dep_found=True
                            if not dep_found:
                                g.appendError(msg='Cartridge {} is selected to be installed but dependent cartridge {} is not'. format(c['name'],dep['name']))
        # Iteration over cartridges is done, now check if the required fields were found in the for-loop
        if cpfsFound==False:
            g.appendError(msg='You need to specify a cartridge for the Cloud Pak Foundational Services (cpfs or cp-foundation)')
        if cpdPlatformFound==False:
            g.appendError(msg='You need to specify a cartridge for the Cloud Pak for Data platform (cpd_platform or lite)')
        
        
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
