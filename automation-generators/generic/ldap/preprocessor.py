from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# ldap:
# - name: cp4d-1-openldap
#   ldap_url: ldap://openldap.cp4d-1-openldap.svc:389
#   ldap_base_dn: dc=ldap-1,dc=internal
#   ldap_bind_dn: cn=admin,dc=ldap-1,dc=internal
#   ldap_bind_password_vault_secret: cpd-511-cp4d-1-openldap-openldap-bind-password
#   ldap_group_filter: (&(cn=%v)(objectclass=groupOfUniqueNames))
#   ldap_group_id_map: *:cn
#   ldap_group_member_id_map: groupOfUniqueNames:uniqueMember
#   ldap_user_filter: (&(uid=%v)(objectclass=inetOrgPerson))
#   ldap_user_id_map: *:uid

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('project').expandWith('cp4d[*]',remoteIdentifier='project')
    g('ldap_url').isRequired()
    g('ldap_base_dn').isRequired()
    g('ldap_bind_dn').isRequired()
    g('ldap_bind_password_vault_secret').isRequired()
    g('ldap_group_filter').isRequired()
    g('ldap_group_id_map').isRequired()
    g('ldap_group_member_id_map').isRequired()
    g('ldap_user_filter').isRequired()
    g('ldap_user_id_map').isRequired()

    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        if "ldap_case_insensitive" in ge:
            if type(ge['ldap_case_insensitive']) != bool:
                g.appendError(msg='Attribute ldap_case_insensitive must be either True or False if specified. Default is False.')


    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result