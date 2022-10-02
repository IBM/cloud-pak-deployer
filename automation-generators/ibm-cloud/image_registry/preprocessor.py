from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# image_registry:
# - name: cpd405
#   registry_host_name: de.icr.io
#   registry_namespace: cpd405

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('registry_host_name').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()

        if 'registry_namespace' not in ge:
            g.appendError(msg='Registry namespace is required for IBM Container Registry')

        if not ge['registry_host_name'].endswith('.icr.io'):
            g.appendError(msg='Only IBM Container Registry can be used as a private registry on IBM Cloud. Host name must end with .icr.io')

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result