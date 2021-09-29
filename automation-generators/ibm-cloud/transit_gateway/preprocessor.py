from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    tgw = g.getExpandedAttributes()

    g('name').isRequired()
    g('location').isRequired()

    if 'connections' in tgw:
        for conn in tgw['connections']:
            if 'vpc' not in conn:
                g.appendError(msg='property vpc must be specified for all elements in list connections')


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result