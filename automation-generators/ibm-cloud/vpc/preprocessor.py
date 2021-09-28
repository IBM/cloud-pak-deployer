from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()


    # allow_inbound is optional, but when it is defined it needs to reference the name of a security rule
    g('allow_inbound').isOptional().mustBeOneOf('security_rule[*]')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


