from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    if len(g.getErrors()) == 0:    
        sr = g.getExpandedAttributes()
        #g('type').isRequired().mustBeOneOf(['tcp','udp','icmp'])
        if "tcp" in sr:
            g('tcp.port_min').isRequired()        
            g('tcp.port_max').isRequired()

            if 'port_min' in sr['tcp']:
                if sr['tcp']['port_min'] > 65535 or sr['tcp']['port_min'] < 1:
                    g.appendError(msg='tcp.port_min must be in range 1 - 65535.')
            if 'port_max' in sr['tcp']:
                if sr['tcp']['port_max'] > 65535 or sr['tcp']['port_max'] < 1:
                    g.appendError(msg='tcp.port_max must be in range 1 - 65535.')
            if 'port_min' in sr['tcp'] and 'port_max' in sr['tcp']:
                if sr['tcp']['port_max'] < sr['tcp']['port_min']:
                    g.appendError(msg='tcp.port_max can not be less than tcp.port_min.')
            
        if "udp" in sr:
            g('udp.port_min').isRequired()
            g('udp.port_max').isRequired()  

            if 'port_min' in sr['udp']:  
                if sr['udp']['port_min'] > 65535 or sr['udp']['port_min'] < 1:
                    g.appendError(msg='udp.port_min must be in range 1 - 65535.')
            if 'port_max' in sr['udp']:               
                if sr['udp']['port_max'] > 65535 or sr['udp']['port_max'] < 1:
                    g.appendError(msg='udp.port_max must be in range 1 - 65535.')
            if 'port_min' in sr['udp'] and 'port_max' in sr['udp']:
                if sr['udp']['port_max'] < sr['udp']['port_min']:
                    g.appendError(msg='udp.port_max can not be less than udp.port_min.')

        if "icmp" in sr:
            g('icmp.code').isRequired()
            g('icmp.type').isRequired()

            if 'code' in sr['icmp']:
                if sr['icmp']['code'] > 255 or sr['icmp']['code'] < 0:
                    g.appendError(msg='icmp.code must be in range 0 - 255.')
            if 'type' in sr['icmp']:
                if sr['icmp']['type'] > 254 or sr['icmp']['type'] < 0:
                    g.appendError(msg='icmp.type must be in range 0 - 254.')        

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result