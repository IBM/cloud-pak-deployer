from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating
# ibm_storage:
# - openshift_cluster_name: "{{ env_id }}"
#   install_br: True

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('install_br').isOptional().mustBeOneOf([True, False])

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result