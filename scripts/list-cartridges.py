from benedict import benedict
import sys

command=sys.argv[1]
input_file=sys.argv[2]
if len(sys.argv)>3:
    cartridge_name=sys.argv[3]

d=benedict(input_file, format='yaml')

if command=='get-cartridges':
    cartridge_list=''
    for c in d['cp4d'][0]['cartridges']:
        if 'state' in c:
            if cartridge_list!="":
                cartridge_list+=' '+c['name']
            else:
                cartridge_list=c['name']
    print(cartridge_list)

if command=='set-removed':
    cartridges=d['cp4d'][0]['cartridges']
    for c in cartridges:
        if 'state' in c:
            c.update({'state': 'removed'})
    d['cp4d'][0]['cartridges']=cartridges
    with open(input_file, 'w') as f:
        f.write(d.to_yaml())
    
if command=='set-installed':
    cartridges=d['cp4d'][0]['cartridges']
    for c in cartridges:
        if c['name']==cartridge_name:
            c.update({'state': 'installed'})
            if 'dependencies' in c:
                for dc in cartridges:
                    if dc['name']==cartridge_name:
                        dc.update({'state': 'installed'})
    d['cp4d'][0]['cartridges']=cartridges
    with open(input_file, 'w') as f:
        f.write(d.to_yaml())

