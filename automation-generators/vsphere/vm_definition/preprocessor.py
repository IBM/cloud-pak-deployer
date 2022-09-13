from generatorPreProcessor import GeneratorPreProcessor

# Validating:
# ---
# vm_definition:
# - name: control-plane
#   vcpu: 8
#   memory_mb: 32768
#   boot_disk_size_gb: 100
# - name: compute
#   vcpu: 16
#   memory_mb: 65536
#   boot_disk_size_gb: 200
# - name: storage
#   vcpu: 10
#   memory_mb: 32768
#   boot_disk_size_gb: 100
#   datastore: Datastore1
#   network: "VM Network"


def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('vcpu').isRequired()
    g('memory_mb').isRequired()
    g('boot_disk_size_gb').isRequired()
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


