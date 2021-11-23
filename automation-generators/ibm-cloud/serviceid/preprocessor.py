from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()

    fc = g.getFullConfig()
    ge=g.getExpandedAttributes()

    if 'servicekeys' in ge:
        for servicekey in ge['servicekeys']:
            if 'name' not in servicekey:
                g.appendError(msg='property name must be specified for all elements in list servicekeys')


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


