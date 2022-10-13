from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('location').isRequired()
    g('connections').isRequired()

    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        tgw = g.getExpandedAttributes()

        vpc_names = []
        if 'vpc' in fc:
            vpc_names = fc.match('vpc[*].name')

        if 'connections' in tgw:
            for conn in tgw['connections']:
                if 'vpc' not in conn:
                    g.appendError(msg='property vpc must be specified for all elements in list connections')
                else:
                    if conn['vpc'] not in vpc_names:
                        g.appendError(msg="'"+conn['vpc']+ "' is not an existing VPC name (Found VPCs: ["+ ','.join(vpc_names) +"] )")


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result