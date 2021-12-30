from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# openshift_logging:
# - openshift_cluster_name: {{ env_id }}
#   logging_output:
#   - name: loki-application
#     type: loki
#     url: https://loki-application.sample.com
#     certificates:
#       cert: {{ env_id }}-loki-cert
#       key: {{ env_id }}-loki-key
#       ca: {{ env_id }}-loki-ca
#   - name: loki-audit
#     type: loki
#     url: https://loki-audit.sample.com
#     certificates:
#       cert: {{ env_id }}-loki-cert
#       key: {{ env_id }}-loki-key
#       ca: {{ env_id }}-loki-ca

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('openshift_cluster_name').isRequired()
    g('logging_output').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        for lo in ge['logging_output']:
            if "name" not in lo:
                g.appendError(msg='Attribute name must be specified for all logging_output entries')
            if "type" not in lo:
                g.appendError(msg='Attribute type must be specified for all logging_output entries')
            elif lo['type'] != "loki":
                g.appendError(msg='Type of logging_output entry must be one of: loki')
            if "url" not in lo:
                g.appendError(msg='Attribute url must be specified for all logging_output entries')
            if "certificates" not in lo:
                g.appendError(msg='Attribute certificates must be specified for all logging_output entries')
            else:
                loc=lo['certificates']
                if "cert" not in loc:
                    g.appendError(msg='Certificate must be specified for logging_output certificates')
                if "key" not in loc:
                    g.appendError(msg='Key must be specified for logging_output certificates')
                if "ca" not in loc:
                    g.appendError(msg='CA bundle must be specified for logging_output certificates')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result