from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()

    g('infrastructure.type').isRequired()
    if(g('infrastructure.type')=='vpc'):
        g('infrastructure.vpc_name').expandWith('vpc[*]').isRequired().mustBeOneOf('vpc[*]')
        g('infrastructure.subnet').expandWith('subnet[*]').isRequired().mustBeOneOf('subnet[*]')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


