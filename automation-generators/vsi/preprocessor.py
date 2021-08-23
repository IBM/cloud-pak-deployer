import json

# TODO: put all return types and structs to a external module


def preprocessor(attributes=None, full_config=None):
    result = {
        'attributes_updated': {},
        'errors':[]
    }
    # check if the vpc is defined
    #print(full_config)
    if 'infrastructure' in attributes:
        if 'vpc' not in attributes['infrastructure']:
            # check how many vpcs are defined
            if len(full_config.get('vpc')) == 1:
                attributes['infrastructure']['vpc'] = full_config.get('vpc')[0].get('name')
            else:
                # add an error to the output
                result['errors'].append({
                    'message': "Can't find a unique definition of a VPC"
                })
    return result