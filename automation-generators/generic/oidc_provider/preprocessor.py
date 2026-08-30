from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# oidc_provider:
# - name: ibm-oidc
#   discovery_url: "https://keycloak-ibm-keycloak.apps.itz-l43q72.hub04-lb.techzone.ibm.com/realms/master/.well-known/openid-configuration"
#   client_id: ibm-oidc
#   client_secret: ibm-oidc-client-secret
#   token_attribute_mappings:
#     groups: "groupIds"
#     given_name: "given_name"
#     family_name: "family_name"
#     first_name: "given_name"
#     last_name: "family_name"
#     sub: "uid"
#     email: "email"

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('discovery_url').isRequired()
    g('client_id').isRequired()
    g('client_secret').isRequired()
    g('token_attribute_mappings').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result