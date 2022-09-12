from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    g('name').isRequired()

    # if there is only one address_prefix defined
    # we can expand values from there
    g('address_prefix').expandWith('address_prefix[*]', remoteIdentifier='name').isRequired()

    # infer the vpc from the given address_prefix
    # look up address_prefix by its name (localProp.address_prefix)
    g('vpc').lookupFromProperty('address_prefix','address_prefix','vpc').isRequired()
    g('ipv4_cidr_block').lookupFromProperty('address_prefix','address_prefix','cidr').isRequired()
    g('zone').lookupFromProperty('address_prefix','address_prefix','zone').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


