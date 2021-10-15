from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('name').isRequired()
    g('managed').isOptional().mustBeOneOf([True,False])


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result