from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    sr = g.getExpandedAttributes()

    #g('type').isRequired().mustBeOneOf(['tcp','udp','icmp'])
    if "tcp" in sr:
        g('tcp.port_min').isRequired()
        g('tcp.port_max').isRequired()
    if "udp" in sr:
        g('udp.port_min').isRequired()
        g('udp.port_max').isRequired()
    if "icmp" in sr:
        g('icmp.code').isRequired()
        g('icmp.type').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result