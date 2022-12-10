from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# cp4d_audit_config:
# - project: zen-19
#   audit_replicas: 2
#   audit_output:
#   - type: openshift-logging
#     logging_name: loki-audit
#     labels:
#       cluster_name: "{{ env_id }}"

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('project').isRequired()
    g('audit_replicas').isOptional()
    g('audit_output').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        for ao in ge['audit_output']:
            if "type" not in ao:
                g.appendError(msg='Attribute type must be specified for all audit_output entries')
            elif ao['type'] != "openshift-logging":
                g.appendError(msg='Type of audit_output entry must be one of: openshift-logging')
            if "logging_name" not in ao:
                g.appendError(msg='Attribute logging_name must be specified for all audit_output entries')
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result