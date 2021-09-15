from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').mustBeDefined()

    # if there is only one address_prefix defined
    # we can expand values from there
    g('address_prefix').expandWith('address_prefix[*].name').mustBeDefined()

    # infer the vpc from the given address_prefix
    # look up address_prefix by its name (localProp.address_prefix)
    g('vpc').lookupFromProperty('address_prefix','address_prefix','vpc').mustBeDefined()

    # do the same for the cidr now
    g('cidr').lookupFromProperty('address_prefix','address_prefix','cidr').mustBeDefined()
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


