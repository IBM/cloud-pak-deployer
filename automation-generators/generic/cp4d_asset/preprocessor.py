from generatorPreProcessor import GeneratorPreProcessor
import sys

# Validating:
# ---
# cp4d_asset:
# - name: sample-assets
#   project: cpd
#   asset_location: assets

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('name').isRequired()
    g('project').isRequired()
    g('asset_location').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result