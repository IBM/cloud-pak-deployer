from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined().mustBeOneOf('vpc[*].name')
    
    if(g('infrastructure.type')=='vpc'):
        g('infrastructure.vpc_name').mustBeDefined()

    result = {
        'attributes_updated': {},
        'errors': {}
    }
    return result