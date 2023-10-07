from generatorPreProcessor import GeneratorPreProcessor

# nfs_server:
# - name: {{ env_id }}-nfs
#   infrastructure:
#     type: vpc
#     subnet: {{ env_id }}-subnet
#     zone: {{ ibm_cloud_region }}-1
#     primary_ipv4_address: 10.231.0.197
#     bastion_host: {{ env_id }}-bastion
#     storage_profile: 10iops-tier
#     volume_size_gb: 1000
#     storage_folder: /data/nfs    
#     keys:
#     - "{{ env_id }}-provision"

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    g('name').isRequired()
    g('infrastructure').isRequired()

    if len(g.getErrors()) == 0:
        g('infrastructure.type').isRequired().mustBeOneOf(['vpc'])
        g('infrastructure.vpc_name').expandWith('vpc[*]').isRequired().mustBeOneOf('vpc[*]')
        g('infrastructure.subnet').expandWith('subnet[*]').isRequired().mustBeOneOf('subnet[*]')
        g('infrastructure.zone').lookupFromProperty('infrastructure.subnet','subnet','zone').isRequired()
        g('infrastructure.volume_size_gb').isRequired()
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


