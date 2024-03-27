from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# zen_access_control:
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

    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('project').expandWith('cp4d[*]',remoteIdentifier='project')
    g('user_groups').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        if 'keycloak_name' in ge and 'demo_openldap_name' in ge:
             g.appendError(msg="If keycloak_name is defined, demo_openldap_name must not be defined. You cannot reference more than 1 external IdP.")

        for user_group in ge['user_groups']:
            if 'name' not in user_group:
                g.appendError(msg="The name attribute is mandatory for each user_group")

            if 'roles' not in user_group:
                g.appendError(msg="The roles attribute is mandatory for each user_group")
            elif not (isinstance(user_group['roles'], list)):
                g.appendError(msg="Every user group must have at least one role")

            if 'keycloak_groups' in user_group and 'keycloak_name' not in ge:
                g.appendError(msg="If keycloak_groups are defined, the zen_access_control must reference a keycloak_name")

            if 'ldap_groups' in user_group and 'demo_openldap_name' not in ge:
                g.appendError(msg="If ldap_groups are defined, the zen_access_control must reference a demo_openldap_name")

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result