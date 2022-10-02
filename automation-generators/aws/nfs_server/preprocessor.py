from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    
    #Level 1
    g('name').isRequired()
    g('infrastructure').isRequired()
    #Level 2
    if len(g.getErrors()) == 0:
        g('infrastructure.aws_region').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


