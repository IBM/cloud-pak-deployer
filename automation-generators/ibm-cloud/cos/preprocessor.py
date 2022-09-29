from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    g('name').isRequired()
    g('plan').isRequired()
    g('location').isRequired()

    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge = g.getExpandedAttributes()

        if 'buckets' in ge:
            for bucket in ge['buckets']:
                if 'name' not in bucket:
                    g.appendError(msg='property name must be specified for all elements in list buckets')
                if 'cross_region_location' in bucket:
                    if ('region_location' in bucket) or ('single_site_location' in bucket):
                        g.appendError(msg='only one property of cross_region_location, region_location, single_site_location can be specified at the same time')
                if 'region_location' in bucket:
                    if ('cross_region_location' in bucket) or ('single_site_location' in bucket):
                        g.appendError(msg='only one property of cross_region_location, region_location, single_site_location can be specified at the same time')
                if 'single_site_location' in bucket:
                    if ('region_location' in bucket) or ('cross_region_location' in bucket):
                        g.appendError(msg='only one property of cross_region_location, region_location, single_site_location can be specified at the same time')

        if 'serviceids' in ge:
            serviceid_names = []
            if 'serviceid' in fc:
                serviceid_names = fc.match('serviceid[*].name')
            for serviceid in ge['serviceids']:
                if "name" not in serviceid:
                    g.appendError(msg='name must be specified when defining a bucket')
                else:
                    if serviceid['name'] not in serviceid_names:
                        g.appendError(msg="'"+ serviceid['name'] + "' is not an existing serviceid name (Found nfs_server: ["+ ','.join(serviceid_names) +"] )")
                
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result


