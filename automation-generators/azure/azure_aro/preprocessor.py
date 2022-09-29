from generatorPreProcessor import GeneratorPreProcessor


def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    g('name').isRequired()

    g('resource_group').isRequired()
    g('resource_group.name').isRequired()
    g('resource_group.location').isRequired()

    g('vnet').isRequired()
    g('vnet.name').isRequired()
    g('vnet.address_space').isRequired()

    g('control_plane').isRequired()
    g('control_plane.subnet').isRequired()
    g('control_plane.subnet.name').isRequired()
    g('control_plane.subnet.address_prefixes').isRequired()
    g('control_plane.vm').isRequired()
    g('control_plane.vm.size').isRequired()

    g('compute').isRequired()
    g('compute.subnet').isRequired()
    g('compute.subnet.name').isRequired()
    g('compute.subnet.address_prefixes').isRequired()
    g('compute.vm').isRequired()
    g('compute.vm.size').isRequired()
    g('compute.vm.disk_size_gb').isRequired()
    g('compute.vm.count').isRequired()  

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result