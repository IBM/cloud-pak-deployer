from benedict import benedict
import os
import base64, json, yaml
import sys

p_all_config=sys.argv[1]
cartridge_name=sys.argv[2]

all_config=benedict(yaml.load(base64.b64decode(p_all_config), Loader=yaml.FullLoader))

# First disable all cartridges
cartridges=all_config['cp4d'][0]['cartridges']
for c in cartridges:
    if 'state' in c:
        c.update({'state': 'removed'})
all_config['cp4d'][0]['cartridges']=cartridges

# Enable the specified cartridges and all dependencies
cartridges=all_config['cp4d'][0]['cartridges']
for c in cartridges:
    if c['name']==cartridge_name:
        c.update({'state': 'installed'})
        if 'dependencies' in c:
            for dependent_cartridge in c['dependencies']:
                for dc in cartridges:
                    if dc['name']==dependent_cartridge['name']:
                        dc.update({'state': 'installed'})
all_config['cp4d'][0]['cartridges']=cartridges

# Print the output
print(json.dumps({
    'updated_config': all_config,
    }, indent=4, separators=(',', ': ')))