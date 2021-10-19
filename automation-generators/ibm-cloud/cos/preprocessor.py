from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('plan').isRequired()
    g('location').isRequired()

    ge=g.getExpandedAttributes()
    if 'buckets' in ge:
        for bucket in ge['buckets']:
            if 'name' not in bucket:
                g.appendError(msg='property name must be specified for all elements in list buckets')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


