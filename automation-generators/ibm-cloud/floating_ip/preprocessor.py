from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('zone').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result