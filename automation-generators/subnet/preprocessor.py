from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined()

    # if there is only one address_prefix defined
    # we can expand values from there
    g('address_prefix').expandWith('address_prefix[*].name').mustBeDefined()
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


