from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating
# ibm_storage:
# - openshift_cluster_name: "{{ env_id }}"
#   install_br: True

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('backup_restore').isOptional()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()
        if 'backup_restore' in ge:
            if 'install' in ge['backup_restore']:
                if type(ge['backup_restore']['install']) != bool:
                    g.appendError(msg='Attribute backup_restore must be either true or false if specified. Default is false.')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result