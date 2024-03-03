from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# cp4d_role:
# - project: cpd
#   openshift_cluster_name: {{ env_id }}
#   name: My Test Role
#   description: My Test Role Description
#   state: installed|removed
#   permissions:
#     - manage_catalog
#     - monitor_project
#     - manage_groups

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('project').expandWith('cp4d[*]',remoteIdentifier='project')
    g('name').isRequired()
    g('state').mustBeOneOf(['installed', 'removed'])
    g('description').isRequired()
    g('permissions').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        if not (isinstance(ge['permissions'], list)):
            g.appendError(msg="Every role must at least have 1 permission")

        if ge['state'] not in ['installed','removed']:
            g.appendError(msg='cp4d_role state must be "installed" or "removed"')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result