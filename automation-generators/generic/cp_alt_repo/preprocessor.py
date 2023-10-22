from generatorPreProcessor import GeneratorPreProcessor
import sys, os
import re


def str_to_bool(s):
    if s == None:
        return False
    else:
        return s.lower() in ['true','yes','1']

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    global g
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)
    
    g('repo').isRequired()
    g('registry_pull_secrets').isRequired()
    g('registry_mirrors').isRequired()

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        g('repo.token_secret').isRequired()
        g('repo.cp_path').isRequired()
        g('repo.fs_path').isRequired()
        g('repo.opencontent_path').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result