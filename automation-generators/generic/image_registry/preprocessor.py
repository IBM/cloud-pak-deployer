from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# image_registry:
# - name: cpd405
#   registry_host_name: nfs.coc.ibm.com
#   registry_port: 15000
#   registry_namespace: cpd405
#   registry_insecure: false
#   registry_trusted_ca_secret: nfs-trusted-ca

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('registry_host_name').isRequired()
    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        fc = g.getFullConfig()
        ge=g.getExpandedAttributes()

        if "registry_insecure" in ge:
            if type(ge['registry_insecure']) != bool:
                g.appendError(msg='Attribute registry_insecure must be either true or false if specified. Default is false.')
            if 'registry_trusted_ca_secret' in ge:
                g.appendError(msg='Attribute registry_trusted_ca_secret cannot be specified if registry_insecure also specified.')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result