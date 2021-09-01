from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined()
    #g('allow_inbound')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': []
    }
    return result


