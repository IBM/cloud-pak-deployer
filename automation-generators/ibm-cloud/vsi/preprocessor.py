from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()

    g('infrastructure.type').isRequired().mustBeOneOf(['vpc'])
    if(g('infrastructure.type')=='vpc'):
        g('infrastructure.allow_ip_spoofing').isOptional().mustBeOneOf([True,False])
        g('infrastructure.keys').isRequired()
        g('infrastructure.image').isRequired()
        g('infrastructure.subnet').expandWith('subnet[*]').isRequired().mustBeOneOf('subnet[*]')
        g('infrastructure.vpc_name').expandWith('vpc[*]').isRequired().mustBeOneOf('vpc[*]')
        g('infrastructure.primary_ipv4_address').isOptional()
        g('infrastructure.public_ip').isOptional()
        g('infrastructure.zone').lookupFromProperty('infrastructure.subnet','subnet','zone').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


