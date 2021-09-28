from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('zone').isRequired()
    g('cidr').isRequired()

    g('vpc').expandWith('vpc[*]',remoteIdentifier='name').isRequired()
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


