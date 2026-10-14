from generatorPreProcessor import GeneratorPreProcessor
import sys, os
import re

# Reference
# ---

# openshift:
# - name: sample
#   ocp_version: 4.20
#   compute_nodes: 3
#   infrastructure:
#     type: self-managed
#   openshift_storage:
#   - storage_name: odf-storage
#     storage_type: odf
#     odf_storage_label: ocs
#     odf_storage_size_gb: 500

# Validating:
# ---

# ---
# ibm_bob:
# - project: ibm-bob
#   operators_project: ibm-bob-operators     # defaults to <project>-operators
#   openshift_cluster_name: "{{ env_id }}"
#   openshift_storage_name: odf-storage
#   ibm_bob_version: 2.0.0                   # or: latest
#   accept_licenses: False
#   reuse_existing_cert_manager: False        # default False. If True, reuse a cert-manager that was installed
#                                             # outside OLM instead of installing the Red Hat cert-manager
#   state: installed                          # only 'installed' in iteration 1
#   premium_packages:
#     rag: False
#     z_proxy: False                          # requires rag: True
#     understand: False
#   # Model gateway (optional) — see https://bob.ibm.com/docs/ide/enterprise/on-premises/model-gateway/configuration
#   # If omitted, Bob installs with an empty model gateway config.
#   model_gateway:
#     models: [...]
#     routers: [...]
#   # For each env.<VAR> in model_gateway, map the var name to a deployer vault secret name.
#   model_gateway_secret_names:
#     AZURE_API_KEY: ibm-bob-azure-api-key
#   image_registry_name: registry-name   # Required when CPD_AIRGAP is true

PREMIUM_PACKAGES = ['rag', 'z_proxy', 'understand']

def find_env_references(node, found=None):
    """Collect the VAR names of all 'env.VAR' string values in the model gateway config."""
    if found is None:
        found = set()
    if isinstance(node, dict):
        for key, value in node.items():
            # x-providers is a scratchpad that the model gateway ignores
            if key != 'x-providers':
                find_env_references(value, found)
    elif isinstance(node, list):
        for value in node:
            find_env_references(value, found)
    elif isinstance(node, str) and node.startswith('env.') and len(node) > 4:
        found.add(node[4:])
    return found

def str_to_bool(s):
    if s == None:
        return False
    else:
        return s.lower() in ['true','yes','1']

def preprocessor(attributes=None, fullConfig=None, moduleVariables=None):
    global g
    g = GeneratorPreProcessor(attributes,fullConfig,moduleVariables)

    g('project').isRequired()
    g('operators_project').isOptional()
    g('openshift_cluster_name').expandWith('openshift[*]',remoteIdentifier='name')
    g('ibm_bob_version').isRequired()
    g('accept_licenses').isOptional().mustBeOneOf([True, False])
    g('reuse_existing_cert_manager').isOptional().mustBeOneOf([True, False])
    g('state').isOptional().mustBeOneOf(['installed', 'removed'])
    g('premium_packages').isOptional()
    g('model_gateway').isOptional()
    g('model_gateway_secret_names').isOptional()

    # Expand storage only when installing (not needed for removal)
    if len(g.getErrors()) == 0:
        _state = g.getExpandedAttributes().get('state', 'installed')
        if _state != 'removed':
            openshift_cluster_name=g('openshift_cluster_name').getExpandedAttributes()['openshift_cluster_name']
            g('openshift_storage_name').expandWithSub('openshift', remoteIdentifier='name', remoteValue=openshift_cluster_name, listName='openshift_storage',listIdentifier='storage_name')

    # Now that we have reached this point, we can check the attribute details if the previous checks passed
    if len(g.getErrors()) == 0:
        ge=g.getExpandedAttributes()
        _removing = ge.get('state', 'installed') == 'removed'

        # Check that version is latest or matches x.y.z pattern
        if ge['ibm_bob_version'] != 'latest' and \
            not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+$",str(ge['ibm_bob_version'])):
            g.appendError(msg="ibm_bob_version must be latest or in the format of x.y.z, for example 2.0.0")

        # Install-only checks: skip when removing
        if not _removing:
            # Check premium packages: only known keys, boolean values, z_proxy requires rag
            if 'premium_packages' in ge:
                premium_packages=ge['premium_packages']
                if not isinstance(premium_packages, dict):
                    g.appendError(path='premium_packages', msg="premium_packages must be a dictionary with keys: {}".format(', '.join(PREMIUM_PACKAGES)))
                else:
                    for key, value in premium_packages.items():
                        if key not in PREMIUM_PACKAGES:
                            g.appendError(path='premium_packages', msg="Unknown premium package {}, must be one of: {}".format(key, ', '.join(PREMIUM_PACKAGES)))
                        elif not isinstance(value, bool):
                            g.appendError(path='premium_packages', msg="premium_packages.{} must be True or False".format(key))
                    if premium_packages.get('z_proxy') is True and premium_packages.get('rag') is not True:
                        g.appendError(path='premium_packages', msg="premium_packages.z_proxy requires premium_packages.rag to be True")

            # Check model gateway: secrets are vault secret names, and every env.VAR must have one
            secret_names = ge.get('model_gateway_secret_names', {})
            if not isinstance(secret_names, dict) or \
                not all(isinstance(v, str) and v != '' for v in secret_names.values()):
                g.appendError(path='model_gateway_secret_names', msg="model_gateway_secret_names must map environment variable names to vault secret names")
                secret_names = {}
            if 'model_gateway' in ge:
                if not isinstance(ge['model_gateway'], dict):
                    g.appendError(path='model_gateway', msg="model_gateway must be a dictionary with the model gateway configuration (models, routers)")
                else:
                    for var in sorted(find_env_references(ge['model_gateway']) - set(secret_names.keys())):
                        g.appendError(path='model_gateway_secret_names', msg="model_gateway references env.{} but model_gateway_secret_names has no vault secret for {}".format(var, var))
            elif secret_names:
                g.appendError(path='model_gateway_secret_names', msg="model_gateway_secret_names can only be specified together with model_gateway")

            # If air-gapped install, image registry name must be specified
            if str_to_bool(os.environ.get('CPD_AIRGAP')):
                if 'image_registry_name' not in ge:
                    g.appendError(msg="When doing an air-gapped install, the image_registry_name must be specified for the ibm_bob object")

        # License check: skip when removing (same as ACTION=destroy)
        if not _removing and os.environ.get('ACTION') != 'destroy':
            accept_licenses = ge.get('accept_licenses', False)
            if not accept_licenses:
                if not str_to_bool(os.environ.get('CPD_ACCEPT_LICENSES')):
                    g.appendError(msg="You must accept licenses by specifying accept_licenses: True or by using the --accept-all-licenses command line flag")

        # Set operators project to <project>-operators if not explicitly configured
        if not 'operators_project' in ge:
            g('operators_project').set('{}-operators'.format(ge['project']))

        if not 'state' in ge:
            g('state').set('installed')

        # Check reference: the OpenShift cluster and storage must exist
        fc = g.getFullConfig()
        if 'openshift' in fc:
            openshift_names = fc.match('openshift[*].name')
            if 'openshift_cluster_name' in ge:
                if ge['openshift_cluster_name'] not in openshift_names:
                    g.appendError(msg="Was not able to find an OpenShift cluster with name: "+ge['openshift_cluster_name'])
                else:
                    for cluster_index in range(len(fc['openshift'])):
                        if fc['openshift'][cluster_index].get('name',None) == ge['openshift_cluster_name']:
                            if 'openshift_storage' not in fc['openshift['+str(cluster_index)+']']:
                                g.appendError(msg="The cluster '"+ ge['openshift_cluster_name'] +"' has no attribute openshift_storage")
                            else:
                                remote_storage_names = fc.match('openshift['+str(cluster_index)+'].openshift_storage[*].storage_name')
                                if 'openshift_storage_name' in ge:
                                    if ge['openshift_storage_name'] not in remote_storage_names:
                                        g.appendError(msg="The cluster with name "+ ge['openshift_cluster_name'] +" doesn't have a openshift_storage element with name "+ge['openshift_storage_name'] +"")

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result
