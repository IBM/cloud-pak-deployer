from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# cp4d_access_control:
# - project: cpd
#   openshift_cluster_name: "{{ env_id }}"
#   keycloak_name: cp-keycloak
#   user_groups:
#   - name: cp4d-admins
#     description: Cloud Pak for Data Administrators
#     roles:
#     - zen_administrator_role
#     keycloak_groups:
#     - kc-cp4d-admins
#   - name: cp4d-data-engineers
#     description: Cloud Pak for Data Data Engineers
#     roles:
#     - zen_user_role
#     keycloak_groups:
#     - kc-cp4d-data-engineers
#   - name: cp4d-data-scientists
#     description: Cloud Pak for Data Data Scientists
#     roles:
#     - zen_user_role
#     keycloak_groups:
#     - kc-cp4d-data-scientists

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('project').isRequired()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('user_groups').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        cp4d_projects = fc.match('cp4d[*].project')
        if ge['project'] not in cp4d_projects:
            g.appendError(msg="Wasn't able to find a cp4d element with project name: "+ge['project']+' ')

        for user_group in ge['user_groups']:
            if 'name' not in user_group:
                g.appendError(msg="The name attribute is mandatory for each user_group")

            if 'roles' not in user_group:
                g.appendError(msg="The roles attribute is mandatory for each user_group")
            elif not (isinstance(user_group['roles'], list)):
                g.appendError(msg="Every user group must have at least one role")

            if 'keycloak_groups' in user_group and 'keycloak_name' not in ge:
                g.appendError(msg="If keycloak_groups are defined, the cp4d_access_control must reference a keycloak_name")
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result