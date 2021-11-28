from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# cp4d_saml_config:
# - project: zen-40
#   entrypoint: "https://prepiam.ice.ibmcloud.com/saml/sps/saml20ip/saml20/login"
#   field_to_authenticate: email
#   sp_cert_secret: {{ env_id }}-zen-40-sp-cert
#   idp_cert_secret: {{ env_id }}-zen-40-idp-cert
#   issuer: "cp4d"
#   identifier_format: ""

def preprocessor(attributes=None, fullConfig=None):
    g = GeneratorPreProcessor(attributes,fullConfig)

    g('project').isRequired()
    g('entrypoint').isRequired()
    g('field_to_authenticate').isRequired()
    g('idp_cert_secret').isRequired()
    g('issuer').isRequired()
    g('identifier_format').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        cp4d_projects = fc.match('cp4d[*].project')
        if ge['project'] not in cp4d_projects:
                    g.appendError(msg="Wasn't able to find a cp4d element with project name: "+ge['project']+' ')
    
    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result