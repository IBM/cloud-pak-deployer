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

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('vpc_name').expandWith('vpc[*]',remoteIdentifier='name')
    g('rules').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()
        for rule in ge['rules']:
            if 'name' not in rule:
                g.appendError(msg='Every rule must have a name')
            if 'action' not in rule:
                g.appendError(msg='Every rule must have action')
            if "action" in rule and rule['action'] not in ['allow','deny']:
                g.appendError(msg='rule action must be allow or deny')
            if 'source' not in rule:
                g.appendError(msg='Every rule must have source')
            if 'destination' not in rule:
                g.appendError(msg='Every rule must have destination')
            if 'direction' not in rule:
                g.appendError(msg='Every rule must have direction')
            if "direction" in rule and rule['direction'] not in ['inbound','outbound']:
                g.appendError(msg='rule direction must be inbound or outbound')    
            if "tcp" in rule:
                if "source_port_min" in rule['tcp']:
                    if rule['tcp']['source_port_min'] > 65535 or rule['tcp']['source_port_min'] < 1:
                       g.appendError(msg='tcp.source_port_min must be in range 1 - 65535.')
                if "source_port_max" in rule['tcp']:
                    if rule['tcp']['source_port_max'] > 65535 or rule['tcp']['source_port_max'] < 1:
                       g.appendError(msg='tcp.source_port_max must be in range 1 - 65535.')   
                if "source_port_min" in rule['tcp'] and "source_port_max" in rule['tcp']:
                    if rule['tcp']['source_port_max'] < rule['tcp']['source_port_min']:
                       g.appendError(msg='tcp.source_port_max can not be less than tcp.source_port_min.')
                
                if "dest_port_min" in rule['tcp']:
                    if rule['tcp']['dest_port_min'] > 65535 or rule['tcp']['dest_port_min'] < 1:
                       g.appendError(msg='tcp.dest_port_min must be in range 1 - 65535.')
                if "dest_port_max" in rule['tcp']:
                    if rule['tcp']['dest_port_max'] > 65535 or rule['tcp']['dest_port_max'] < 1:
                       g.appendError(msg='tcp.dest_port_max must be in range 1 - 65535.')   
                if "dest_port_min" in rule['tcp'] and "dest_port_max" in rule['tcp']:
                    if rule['tcp']['dest_port_max'] < rule['tcp']['dest_port_min']:
                       g.appendError(msg='tcp.dest_port_max can not be less than tcp.dest_port_min.')  
            if "udp" in rule:
                if "source_port_min" in rule['udp']:
                    if rule['udp']['source_port_min'] > 65535 or rule['udp']['source_port_min'] < 1:
                       g.appendError(msg='udp.source_port_min must be in range 1 - 65535.')
                if "source_port_max" in rule['udp']:
                    if rule['udp']['source_port_max'] > 65535 or rule['udp']['source_port_max'] < 1:
                       g.appendError(msg='udp.source_port_max must be in range 1 - 65535.')   
                if "source_port_min" in rule['udp'] and "source_port_max" in rule['udp']:
                    if rule['udp']['source_port_max'] < rule['udp']['source_port_min']:
                       g.appendError(msg='udp.source_port_max can not be less than udp.source_port_min.')
                
                if "dest_port_min" in rule['udp']:
                    if rule['udp']['dest_port_min'] > 65535 or rule['udp']['dest_port_min'] < 1:
                       g.appendError(msg='udp.dest_port_min must be in range 1 - 65535.')
                if "dest_port_max" in rule['udp']:
                    if rule['udp']['dest_port_max'] > 65535 or rule['udp']['dest_port_max'] < 1:
                       g.appendError(msg='udp.dest_port_max must be in range 1 - 65535.')   
                if "dest_port_min" in rule['udp'] and "dest_port_max" in rule['udp']:
                    if rule['udp']['dest_port_max'] < rule['udp']['dest_port_min']:
                       g.appendError(msg='udp.dest_port_max can not be less than udp.dest_port_min.')  
            if "icmp" in rule:
                if "code" in rule['icmp']:
                    if rule['icmp']['code'] > 255 or rule['icmp']['code'] < 0:
                       g.appendError(msg='icmp.code must be in range 0 - 255.')
                if "type" in rule['icmp']:
                    if rule['icmp']['type'] > 254 or rule['icmp']['type'] < 0:
                       g.appendError(msg='icmp.type must be in range 0 - 254.')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result