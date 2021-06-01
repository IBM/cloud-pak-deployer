import yaml, json
import os, math, sys
import pprint

if len(sys.argv) != 3:
    print('Syntax: {} <input directory> <output file name>'.format(sys.argv[0]))
    sys.exit(1)

#config_path = '.'
config_dir=sys.argv[1]
terraform_main_file=sys.argv[2]
templates =	{}

# config stdout
pp = pprint.PrettyPrinter(indent=2)

# some helper functions
def to_kebap_case(snake_cased_input):
    components = snake_cased_input.split('_')
    return str.join('-', components)
def get_name_prefix(prefix_array):
    return str.join('-', prefix_array)+'-'


json_result = {
    "data": {
        "ibm_resource_group": {
            "base": {
                "name": "ibm"
            }
        }
    },
    "resource": {

    }
}

with os.scandir(config_dir + '/templates') as yaml_files:
    for yaml_file in yaml_files:
        parts_of_filename = yaml_file.name.split('.')[0].split('_')
        with open(config_dir + '/templates/' + yaml_file.name) as yaml_content:
            template_dict = yaml.safe_load(yaml_content)
            if parts_of_filename[0] not in templates:
                templates[ parts_of_filename[0] ] = {}
            templates[ parts_of_filename[0] ][ parts_of_filename[1] ] = template_dict
            #print(template_dict)

pp.pprint(templates)

with open(config_dir + '/' + 'vpc.yaml') as root_yaml_content:
    root_dict = yaml.safe_load(root_yaml_content)
    print("--root--")
    #print(root_dict['vpcs'])

    ### define the locals for terraform
    json_result["locals"] = root_dict['locals']

    ### define vpcs
    json_result["resource"]["ibm_is_vpc"] = {}
    json_result["resource"]["ibm_is_vpc_address_prefix"] = {}
    json_result["resource"]["ibm_is_subnet"] = {}
    json_result["resource"]["ibm_is_instance"] = {}
    json_result["resource"]["ibm_is_security_group_rule"] = {}
    json_result["resource"]["ibm_is_floating_ip"] = {}
    json_result["resource"]["ibm_is_volume"] = {}
    json_result["resource"]["ibm_is_public_gateway"] = {}
    json_result["resource"]["ibm_resource_instance"] = {}

    for vpc in root_dict['vpcs']:
        #print(vpc)
        json_result["resource"]["ibm_is_vpc"][ vpc['name'] ] = {
            'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( vpc['name'] ),
            'address_prefix_management': 'manual',
            'resource_group': '${data.ibm_resource_group.base.id}'
        }

        if 'securityrules' in vpc:
            for rule in vpc['securityrules']:
                json_result["resource"]["ibm_is_security_group_rule"][ vpc['name']+'_'+rule ] = {}
                json_result["resource"]["ibm_is_security_group_rule"][ vpc['name']+'_'+rule ].update( templates['securityrule']['default'] )
                json_result["resource"]["ibm_is_security_group_rule"][ vpc['name']+'_'+rule ].update( templates['securityrule'][ rule ] )
                json_result["resource"]["ibm_is_security_group_rule"][ vpc['name']+'_'+rule ].update({
                    'group': '${ibm_is_vpc.' + vpc['name'] + '.default_security_group}'
                })

        if 'public_gateway' in vpc:
            if vpc['public_gateway']:
                json_result["resource"]["ibm_is_public_gateway"][ vpc['name'] ] = {
                    'name': to_kebap_case( 'pgw_'+vpc['name'] ),
                    'vpc': "${ibm_is_vpc."+ vpc['name'] +".id}",
                    'zone': '${local.zone}',
                    'resource_group': '${data.ibm_resource_group.base.id}'
                }
            
        if vpc['address_prefixes']:
            for prefix in vpc['address_prefixes']:
                json_result["resource"]["ibm_is_vpc_address_prefix"][ prefix['name'] ] = {
                    'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( prefix['name'] ),
                    'zone': '${local.zone}',
                    'cidr': prefix['cidr'],
                    'vpc': "${ibm_is_vpc."+ vpc['name'] +".id}"
                }
                if prefix['subnets']: # cheap trick to ensure that subnets is not 'TypeNone'
                    print(vpc['name'] +' - ' + prefix['name'])

                    for subnet in prefix['subnets']:
                        #print('-subnet')
                        #print(subnet)
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ] = {}
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].update( templates['subnet']['default'] )
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].update( subnet )
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].update( {
                            'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( subnet['name'] ),
                            #'zone': '${local.zone}',
                            #'ipv4_cidr_block': subnet['ipv4_cidr_block'],
                            'vpc': "${ibm_is_vpc."+ vpc['name'] +".id}",
                            'depends_on': ['ibm_is_vpc_address_prefix.' + prefix['name']]
                        })
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].pop('roks', None)
                        json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].pop('vsis', None)
                        # if we have a public_gateway definedin the parent vpc,
                        # attach it to the subnet
                        if 'public_gateway' in vpc:
                            if vpc['public_gateway']:
                                json_result["resource"]["ibm_is_subnet"][ subnet['name'] ].update({
                                    'public_gateway': "${ibm_is_public_gateway."+ vpc['name'] +".id}"
                                })
                        ### are there vsis defined inside the subnet?
                        if 'vsis' in subnet:
                            if subnet['vsis']:
                                for vsi in subnet['vsis']:
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ] = {}
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].update(templates['vsi']['default'])
                                    #if vsi['flavour']:
                                    #    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].update(templates['vsi'][ vsi['flavour'] ])
                                    print('instance: '+vsi['name'] + ' image: ' + json_result["resource"]["ibm_is_instance"][ vsi['name'] ]['image'])
                                    if 'addons' in vsi:
                                        if 'storage' in vsi['addons']:
                                            json_result["resource"]["ibm_is_instance"][ vsi['name'] ]['volumes'] = []
                                            for disk in vsi['addons']['storage']:
                                                print('processing storage')
                                                disk_name=vsi['name']+'_'+disk['name']
                                                json_result["resource"]["ibm_is_volume"][ disk_name ] = {
                                                    'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case(disk_name),
                                                    'resource_group': '${data.ibm_resource_group.base.id}',
                                                    'profile': disk['profile'],
                                                    'zone': '${local.zone}',
                                                    'capacity': disk['size']
                                                }
                                                json_result["resource"]["ibm_is_instance"][ vsi['name'] ]['volumes'].append('${ibm_is_volume.'+disk_name+'.id}')
                                                # json_result["resource"]["ibm_is_instance"][ vsi['name'] ].update({
                                                #     'volumes': [ '${ibm_is_volume.'+disk_name+'.id}' ]
                                                # })
                                                
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].update( vsi )
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].update({
                                        'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( vsi['name'] ),
                                        'resource_group': '${data.ibm_resource_group.base.id}',
                                        'zone': '${local.zone}',
                                        'primary_network_interface': {
                                            'name': "eth0",
                                            'subnet': '${ibm_is_subnet.'+ subnet['name'] +'.id}',
                                            'primary_ipv4_address': vsi['primary_ipv4_address']
                                        },
                                        'vpc': "${ibm_is_vpc."+ vpc['name'] +".id}"
                                    })
                                    ### if the vsi is flagged as bastion, attach a public ip to it
                                    if 'bastion' in vsi:
                                        json_result["resource"]["ibm_is_floating_ip"][ vsi['name'] ] = {
                                            'name': get_name_prefix(root_dict['locals']['name_prefix']) +to_kebap_case( vsi['name'] )+'-fip',
                                            'target': '${ibm_is_instance.' + vsi['name'] + '.primary_network_interface[0].id}'
                                        }
                                    ### todo: solve this
                                    # hardcoded cleanup
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].pop('primary_ipv4_address', None)
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].pop('flavour', None)
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].pop('bastion', None)
                                    json_result["resource"]["ibm_is_instance"][ vsi['name'] ].pop('addons', None)
            if 'roks' in vpc:
                if vpc['roks']:
                    json_result["resource"]["ibm_container_vpc_cluster"] = {}
                    for roks in vpc['roks']:
                        ### each cluster requires a COS Instance to store its image registry somewhere
                        json_result["resource"]["ibm_resource_instance"][ roks['name'] ] = {}
                        json_result["resource"]["ibm_resource_instance"][ roks['name'] ].update(templates['service']['cos'])
                        json_result["resource"]["ibm_resource_instance"][ roks['name'] ].update({
                            'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( roks['name'] + '-cos')
                        })
                        ### now define the cluster itself
                        json_result["resource"]["ibm_container_vpc_cluster"][ roks['name'] ] = {}
                        json_result["resource"]["ibm_container_vpc_cluster"][ roks['name'] ].update(templates['roks']['default'])
                        json_result["resource"]["ibm_container_vpc_cluster"][ roks['name'] ].update(roks)
                        json_result["resource"]["ibm_container_vpc_cluster"][ roks['name'] ].update({
                            'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( roks['name'] ),
                            'vpc_id': "${ibm_is_vpc."+ vpc['name'] +".id}",
                            'cos_instance_crn': "${ibm_resource_instance."+ roks['name'] +".id}",
                            'zones': [{
                                'subnet_id': '${ibm_is_subnet.' + vpc['address_prefixes'][0]['subnets'][0]['name'] + '.id}',
                                'name': vpc['address_prefixes'][0]['subnets'][0]['zone']
                            }]
                        })
                        # hardcoded cleanup
                        json_result["resource"]["ibm_container_vpc_cluster"][ roks['name'] ].pop('subnets', None)

    if 'tgw' in root_dict:
        json_result["resource"]["ibm_tg_gateway"] = {}
        json_result["resource"]["ibm_tg_connection"] = {}
        for tgw in root_dict['tgws']:
            json_result["resource"]["ibm_tg_gateway"][ tgw['name'] ] = {}
            json_result["resource"]["ibm_tg_gateway"][ tgw['name'] ].update( tgw )
            json_result["resource"]["ibm_tg_gateway"][ tgw['name'] ].update({
                'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( tgw['name'] ),
                'resource_group': '${data.ibm_resource_group.base.id}'
            })
            for connection in tgw['connections']:
                print('tgw-connection: '+ connection)
                json_result["resource"]["ibm_tg_connection"][ connection ] = {
                    'name': to_kebap_case( 'to-' + connection ),
                    'gateway': '${ibm_tg_gateway.' + tgw['name'] + '.id}',
                    'network_type': "vpc",
                    'network_id': '${ibm_is_vpc.'+ connection +'.resource_crn}'
                }
            # clean up tgw
            json_result["resource"]["ibm_tg_gateway"][ tgw['name'] ].pop('connections', None)

    ### Services
    if 'services' in root_dict:
        for service in root_dict['services']:
            json_result["resource"]["ibm_resource_instance"][ service['name'] ] = {}
            json_result["resource"]["ibm_resource_instance"][ service['name'] ].update(templates['service'][ service['flavour'] ])
            json_result["resource"]["ibm_resource_instance"][ service['name'] ].update({
                'name': get_name_prefix(root_dict['locals']['name_prefix']) + to_kebap_case( service['name'] )
            })

# print(json_result)

with open(terraform_main_file, 'w') as outfile:
    json.dump(json_result, outfile, indent=4)