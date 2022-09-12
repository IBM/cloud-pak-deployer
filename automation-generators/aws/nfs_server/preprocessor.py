from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    g('name').isRequired()
    g('infrastructure').isRequired()
    g('infrastructure.aws_region').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


