from generatorPreProcessor import GeneratorPreProcessor

# Validating:
# ---
# openshift:
# - name: sample
#   ocp_version: 4.6
#   worker_flavour: bx2.16x64
#   worker_count: 1
#   resource_group_name: ibm
#   max_worker_count: 10
#   infrastructure:
#     type: vpc
#     vpc_name: sample
#     subnets: 
#     - sample-subnet-zone-1
#     - sample-subnet-zone-2
#     - sample-subnet-zone-3
#   openshift_storage:
#   - storage_name: nfs-storage
#     storage_type: nfs
#   nfs_server_name: sample-nfs
#   - storage_name: ocs-storage
#     storage_type: ocs
#     ocs_storage_label: ocs
#     ocs_storage_size: 500Gi

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined()
    g('ocp_version').mustBeDefined().mustBeOneOf('4.6')
    g('worker_flavour').mustBeDefined()
    # worker_count must be optional but if referenced it must have a value
    g('worker_count').mustBeDefined()
    g('max_worker_count').mustBeDefined()
    
    # I deliberately made an error by spelling "xinfrastructure" but the validator doesn't seem to care if xinfrastructure is defined or not
    g('xinfrastructure').mustBeDefined()
    # How do I define multiple values?
    g('infrastructure.type').mustBeOneOf('vpc')
    g('infrastructure.vpc_name').expandWith('vpc[*].name')
    g('infrastructure.subnets').mustBeDefined()
    # Subnets must exist and all elements must exist in subnet definitions

    g('openshift_storage').mustBeDefined()
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


