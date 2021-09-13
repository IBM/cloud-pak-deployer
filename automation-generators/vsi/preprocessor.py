from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined()
    
    if(g('infrastructure.type')=='vpc'):
        g('infrastructure.vpc_name').expandWith('vpc[*].name').mustBeDefined().mustBeOneOf('vpc[*].name')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


