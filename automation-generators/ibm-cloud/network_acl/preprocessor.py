from generatorPreProcessor import GeneratorPreProcessor

# network_acl:
# - name: {{ env_id }}-acl
#   vpc_name: {{ env_id }}
#   rules:
#   - name: inbound-ssh
#     action: allow               # Can be allow or deny
#     source: "0.0.0.0/0"
#     destination: "0.0.0.0/0"
#     direction: inbound
#     tcp:
#       source_port_min: 1        # optional
#       source_port_max: 65535    # optional
#       dest_port_min: 22         # optional
#       dest_port_max: 22         # optional
#   - name: output-udp
#     action: deny                # Can be allow or deny
#     source: "0.0.0.0/0"
#     destination: "0.0.0.0/0"
#     direction: output
#     udp:
#       source_port_min: 1        # optional
#       source_port_max: 65535    # optional
#       dest_port_min: 1000       # optional
#       dest_port_max: 2000       # optional
#   - name: output-icmp
#     action: allow               # Can be allow or deny
#     source: "0.0.0.0/0"
#     destination: "0.0.0.0/0"
#     direction: output
#     icmp:
#       code: 1

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    fc = g.getFullConfig()
    tgw = g.getExpandedAttributes()

    g('name').isRequired()
    g('vpc_name').expandWith('vpc[*]',remoteIdentifier='name')
    g('rules').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()
        for rule in ge['rules']:
            if 'name' not in rule:
                g.appendError(msg='Every rule must have a name')
            if "action" in rule and rule['action'] not in ['allow','deny']:
                g.appendError(msg='rule action must be allow or deny')


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result