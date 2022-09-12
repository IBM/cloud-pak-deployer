from generatorPreProcessor import GeneratorPreProcessor

# Validating:
# ---
# vsphere:
# - name: {{ env_id }}
#   vcenter: 10.99.92.13
#   datacenter: Datacenter1
#   datastore: Datastore1
#   cluster: Cluster1
#   network: "VM Network"
#   folder: /Datacenter1/vm/{{ env_id }}

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('vcenter').isRequired()
    g('datacenter').isRequired()
    g('datastore').isRequired()
    g('cluster').isRequired()
    g('network').isRequired()
    g('folder').isRequired()
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


