from generatorPreProcessor import GeneratorPreProcessor
import sys


# Reference
# ---

# openshift:
# - name: sample
#   ocp_version: 4.6
#   worker_flavour: bx2.16x64
#   number_of_workers: 3
#   max_number_of_workers: 10
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
#     ocs_storage_size: 500Gi

# Validating:
# ---

#cp4d:
#- project: zen-40
#  openshift_cluster_name: sample
#  cp4d_version: 4.0
#  openshift_storage_name: nfs-storage
#  cartridges:
#  - name: cp-foundation
#  - name: lite
#    version: not_used
#    subscription_channel: v2.0
#  - name: wsl
#    version: 4.0.1
#    subscription_channel: v2.0
#  - name: wml
#    version: not_used
#    subscription_channel: v1.1
#    size: small
#  - name: wkc
#    version: 4.0.1
#    subscription_channel: v1.0
#    size: small
# - name: ca
#   version: 4.0.1
#   subscription_channel: v4.0
#   size: small
#   instances:
#   - name: ca-instance
#     metastore_ref: ca-metastore
# - name: db2
#   subscription_channel: v1.0
#   size: small
#   version: not_used  
#   instances:
#   - name: ca-metastore
#     metadata_size_gb: 20
#     data_size_gb: 20
#     backup_size_gb: 20  
#     transactionlog_size_gb: 20
# - name: analyticsengine 
#   version: 4.0.1
#   subscription_channel: stable-v1
#   size: small 
# - name: bigsql
#   version: 7.2.1
#   subscription_channel: v7.2
# - name: cde
#   version: 4.0.1
#   subscription_channel: v1.0
# - name: datagate
#   version: 2.0.1
#   subscription_channel: v2.0
# - name: db2wh
#   subscription_channel: v1.0
#   version: not_used
# - name: dmc
#   version: 4.0.1
#   subscription_channel: v1.0
# - name: dods
#   version: 4.0.1
#   subscription_channel: v4.0
#   size: small
# - name: dv
#   version: 1.7.1
#   subscription_channel: v1.7
#   size: small
# - name: mdm
#   version: not_used
#   subscription_channel: v1.1
#   size: small
#   wkc_enabled: true
# - name: openpages
#   version: 8.203.1
#   subscription_channel: v1.0
# - name: planning-analytics
#   version: 4.0.1
#   subscription_channel: v1.0
# - name: rstudio
#   version: not_used
#   subscription_channel: v1.0
#   size: small
# - name: spss
#   version: not_used
#   subscription_channel: v1.0
# - name: watson-openscale
#   version: 4.0.1
#   subscription_channel: v1
#   size: small
# - name: wkc
#   version: 4.0.1
#   subscription_channel: v1.0
#   size: small
# - name: wml
#   version: not_used
#   subscription_channel: v1.1
#   size: small
# - name: wml-accelerator
#   version: 2.3.1
#   subscription_channel: WML-Accelerator-2.3
#   replicas: 1
#   size: small
# - name: wsl
#   version: 4.0.1
#   subscription_channel: v2.0
# - name: db2u
#   version: 4.0.3
#   subscription_channel: v1.1
# - name: db2aaservice
#   version: 4.0.1
#   subscription_channel: v1.0
#   size: small
# - name: iis
#   version: 4.0.1
#   size: small
#   subscription_channel: not_used
# - name: datastage
#   version: 4.0.1
#   subscription_channel: v1.0
#   dependencies:
#   - name: db2u
#   - name: iis
#   - name: db2uaaservice   
# - name: productmaster
#   version: 1.0.0
#   subscription_channel: alpha
#   size: small  
# - name: voice-gateway
#   version: not_used
#   subscription_channel: v1.0
#   replicas: 1  
# - name: watson-assistant
#   version: 4.0.0
#   subscription_channel: v4.0
# - name: watson-discovery
#   version: 4.0.0
#   subscription_channel: v4.0
# - name: watson-speech
#   version: 4.0.0
#   subscription_channel: v4.0
#   stt_size: xsmall
#   tts_size: xsmall


def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('project').isRequired()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('cp4d_version').isRequired()
    g('openshift_storage_name').isRequired()
    g('cartridges').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

# Check for cp4d:     
# Check that cp-foundation element exists
# Check that lite element exists

# Check reference
# - Retrieve the openshift element with name=openshift_cluster_name
# - Within the openshift element retrieve, there must be an openshift_storage element with the name cp4d.openshift_storage_name

        # Iterate over all cartridges to check attributes
        for c in ge['cartridges']:
            if "name" not in c:
                g.appendError(msg='name must be specified for all cartridges elements')
            if "name" in c and c['name'] != "cp-foundation":
                if "subscription_channel" not in c:
                    g.appendError(msg='subscription_channel ust be specified for all cartridges, except for cp-foundation')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


