from generatorPreProcessor import GeneratorPreProcessor
import sys, os

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
#- project: zen-40
#  openshift_cluster_name: sample
#  cp4d_version: 4.0
#  openshift_storage_name: nfs-storage
#  use_case_files: True
#  accept_licenses: False
#  olm_utils: False
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

def preprocessor(attributes=None, fullConfig=None):
    global g
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('project').isRequired()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
    g('cp4wa_version').isRequired()
    g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')
    g('olm_utils').isOptional()
    g('use_case_files').isOptional()
    g('accept_licenses').isOptional()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        # Check for cp4d:     
        # Check that cpfs element exists
        # Check that cpd_platform element exists

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

        # Store olm_utils property
        if 'olm_utils' in ge:
            olm_utils=ge['olm_utils']
        else:
            olm_utils=False
        # Check if olm utils is installed
        if olm_utils:
            if not os.path.exists(os.path.expanduser('~')+'/bin/apply-olm'):
                g.appendError(msg="Container image was not built with olm-utils, cannot specify olm_utils: True")

# Check reference
# - Retrieve the openshift element with name=openshift_cluster_name
# - Within the openshift element retrieve, there must be an openshift_storage element with the name cp4wa.openshift_storage_name
        openshift_names = []
        if 'openshift' in fc:
            openshift_names = fc.match('openshift[*].name')

            if 'openshift_cluster_name' in ge:
                if ge['openshift_cluster_name'] not in openshift_names:
                    g.appendError(msg="Was not able to find an OpenShift cluster with name: "+ge['openshift_cluster_name'])
                else:
                    # we made sure the cluster referenced by openshift_cluster_name exists
                    # now check if it has a openshift_storage with the name cpwa.openshift_storage_name

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

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result
