"""
Tests for ibm-bob-cluster config.yaml template rendering and prerequisite logic.
"""

import sys, os, json, unittest, jinja2, yaml

MODELS_FILE = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-variables/vars/ibm-bob-models.yml'
)
SERVING_TEMPLATES_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-openshift-ai-models/templates'
)
TEMPLATES_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-cluster/templates'
)
SHOW_TEMPLATES_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/80-smoke-tests/ibm-bob-cluster-show/templates'
)

class TestIbmBobClusterTemplate(unittest.TestCase):

    def setUp(self):
        self.loader = jinja2.FileSystemLoader(TEMPLATES_DIR)
        self.env = jinja2.Environment(loader=self.loader)
        self.template = self.env.get_template('config.yaml.j2')

    def test_template_rendering_defaults(self):
        context = {
            '_ibm_bob_version': '2.0.0',
            '_ibm_bob_image_pull_prefix': 'icr.io',
            'ocp_storage_class_file': 'ocs-storagecluster-cephfs',
            'ocp_storage_class_block': 'ocs-storagecluster-ceph-rbd',
            'current_ibm_bob_cluster': {
                'project': 'ibm-bob',
                'operators_project': 'ibm-bob-operators',
                'premium_packages': {
                    'rag': False,
                    'z_proxy': False,
                    'understand': False
                }
            }
        }
        rendered = self.template.render(context)
        data = yaml.safe_load(rendered)

        self.assertEqual(data['global']['operatorNamespace'], 'ibm-bob-operators')
        self.assertEqual(data['global']['instanceNamespace'], 'ibm-bob')
        self.assertEqual(data['global']['fileStorageClass'], 'ocs-storagecluster-cephfs')
        self.assertEqual(data['global']['blockStorageClass'], 'ocs-storagecluster-ceph-rbd')
        self.assertEqual(data['global']['imagePullPrefix'], 'icr.io')
        self.assertEqual(data['global']['imagePullSecretName'], 'ibm-entitlement-key')

        self.assertFalse(data['bob']['rag']['enabled'])
        self.assertFalse(data['bob']['zProxy']['enabled'])
        self.assertFalse(data['bob']['understand']['enabled'])

    def test_template_rendering_premium_packages_enabled(self):
        context = {
            '_ibm_bob_version': '2.0.0',
            '_ibm_bob_image_pull_prefix': 'custom-registry.example.com/bob',
            'ocp_storage_class_file': 'managed-nfs-storage',
            'ocp_storage_class_block': 'managed-nfs-storage',
            'current_ibm_bob_cluster': {
                'project': 'my-bob',
                'operators_project': 'my-bob-ops',
                'premium_packages': {
                    'rag': True,
                    'z_proxy': True,
                    'understand': True
                }
            }
        }
        rendered = self.template.render(context)
        data = yaml.safe_load(rendered)

        self.assertEqual(data['global']['operatorNamespace'], 'my-bob-ops')
        self.assertEqual(data['global']['instanceNamespace'], 'my-bob')
        self.assertEqual(data['global']['imagePullPrefix'], 'custom-registry.example.com/bob')
        self.assertTrue(data['bob']['rag']['enabled'])
        self.assertTrue(data['bob']['zProxy']['enabled'])
        self.assertTrue(data['bob']['understand']['enabled'])

    def test_empty_hash_api_secret_fields_are_omitted(self):
        # An empty hashApiSecretName/KeyName is rejected by the Bob CRD pattern validation
        context = {
            '_ibm_bob_version': '2.0.0',
            '_ibm_bob_image_pull_prefix': 'icr.io',
            'ocp_storage_class_file': 'f',
            'ocp_storage_class_block': 'b',
            'current_ibm_bob_cluster': {'project': 'ibm-bob', 'premium_packages': {}}
        }
        data = yaml.safe_load(self.template.render(context))
        self.assertNotIn('hashApiSecretName', data['bob']['zProxy'])
        self.assertNotIn('hashApiSecretKeyName', data['bob']['zProxy'])

    def test_hash_api_secret_fields_rendered_when_set(self):
        context = {
            '_ibm_bob_version': '2.0.0',
            '_ibm_bob_image_pull_prefix': 'icr.io',
            'ocp_storage_class_file': 'f',
            'ocp_storage_class_block': 'b',
            'current_ibm_bob_cluster': {
                'project': 'ibm-bob',
                'premium_packages': {},
                'z_proxy_hash_api_secret_name': 'my-hash',
                'z_proxy_hash_api_secret_key_name': 'key'
            }
        }
        data = yaml.safe_load(self.template.render(context))
        self.assertEqual(data['bob']['zProxy']['hashApiSecretName'], 'my-hash')
        self.assertEqual(data['bob']['zProxy']['hashApiSecretKeyName'], 'key')

    def test_model_gateway_secrets_rendered(self):
        context = {
            '_ibm_bob_version': '2.0.0',
            '_ibm_bob_image_pull_prefix': 'icr.io',
            'ocp_storage_class_file': 'f',
            'ocp_storage_class_block': 'b',
            '_ibm_bob_model_gateway_secrets': {'AZURE_API_KEY': 'a"b'},
            'current_ibm_bob_cluster': {'project': 'ibm-bob', 'premium_packages': {}}
        }
        data = yaml.safe_load(self.template.render(context))
        self.assertEqual(data['bob']['modelGateway']['secrets']['AZURE_API_KEY'], 'a"b')



class TestModelGatewayGeneratedTemplate(unittest.TestCase):

    def render(self, model_id):
        env = jinja2.Environment(loader=jinja2.FileSystemLoader(TEMPLATES_DIR))
        template = env.get_template('model-gateway-generated.j2')
        with open(MODELS_FILE) as f:
            data = yaml.safe_load(f)
        model = [m for m in data['_ibm_bob_ai_models'] if m['id'] == model_id][0]
        context = {
            'current_ibm_bob_cluster': {'openshift_ai_models': {'core_model': model_id}},
            '_ibm_bob_selected_model': model,
            '_ibm_bob_guardrail_model_defaults': data['_ibm_bob_guardrail_model_defaults'],
            '_ibm_bob_core_model_url': 'http://core',
            '_ibm_bob_guardrail_url': 'http://guard',
        }
        return yaml.safe_load(template.render(context))

    def test_nemotron_super_gateway(self):
        """Bob 2.0.0 does not know nvidia/nemotron/3.5-super: the triple must be left out,
        otherwise bob-inference panics at startup."""
        info = self.render('nemotron-3.5-super')['models'][0]['model_info']
        for key in ('provider', 'family', 'version'):
            self.assertNotIn(key, info)
        self.assertTrue(info['exposed'])
        self.assertEqual(info['mode'], 'chat')
        self.assertEqual(info['max_input_tokens'], 270000)
        self.assertEqual(info['max_output_tokens'], 20000)
        self.assertTrue(info['supports_vision'])

    def test_known_model_keeps_triple(self):
        info = self.render('nemotron-3-ultra')['models'][0]['model_info']
        self.assertEqual((info['provider'], info['family'], info['version']), ('nvidia', 'nemotron', '3-ultra'))
        self.assertTrue(info['exposed'])
        self.assertEqual(info['mode'], 'chat')

    def test_guardrail_slots_keep_triple(self):
        models = {m['model_name']: m for m in self.render('nemotron-3.5-super')['models']}
        for slot in ('security', 'background'):
            info = models[slot]['model_info']
            self.assertEqual((info['provider'], info['family'], info['version']), ('openai', 'gpt-oss', '20b'))
        self.assertEqual(self.render('nemotron-3.5-super')['routers'][0]['static']['default_model'], 'premium-ide')


class TestVllmServingRuntimeTemplate(unittest.TestCase):

    def setUp(self):
        env = jinja2.Environment(loader=jinja2.FileSystemLoader(SERVING_TEMPLATES_DIR))
        env.filters['to_json'] = json.dumps
        self.template = env.get_template('vllm-serving-runtime.j2')

    def test_image_command_port_and_env_rendered(self):
        context = {'_sr_name': 'core', '_sr_namespace': 'ns', '_sr_image': 'vllm/vllm-openai:v0.32.0',
                   '_sr_env': [{'name': 'VLLM_BLOCKSCALE_FP8_GEMM_FLASHINFER', 'value': '0'}]}
        container = yaml.safe_load(self.template.render(context))['spec']['containers'][0]
        self.assertEqual(container['image'], 'vllm/vllm-openai:v0.32.0')
        self.assertEqual(container['command'], ['vllm', 'serve', '/mnt/models'])
        self.assertIn('--port=8080', container['args'])
        self.assertIn('--served-model-name=core', container['args'])
        self.assertEqual(container['ports'][0]['containerPort'], 8080)
        env = {e['name']: e['value'] for e in container['env']}
        self.assertEqual(env['VLLM_BLOCKSCALE_FP8_GEMM_FLASHINFER'], '0')
        self.assertEqual(env['HOME'], '/tmp')

    def test_only_default_env_when_none_given(self):
        context = {'_sr_name': 'core', '_sr_namespace': 'ns', '_sr_image': 'img:1', '_sr_env': []}
        container = yaml.safe_load(self.template.render(context))['spec']['containers'][0]
        self.assertEqual([e['name'] for e in container['env']], ['HOME'])


class TestIbmBobInfoTemplate(unittest.TestCase):

    def setUp(self):
        self.loader = jinja2.FileSystemLoader(SHOW_TEMPLATES_DIR)
        self.env = jinja2.Environment(loader=self.loader)
        self.template = self.env.get_template('ibm-bob-info.j2')

    def test_info_rendering_without_premium_packages(self):
        context = {
            '_ibm_bob_gateway_url': 'https://api.bob.apps.example.com',
            '_ibm_bob_admin_ui_url': 'https://bob.apps.example.com',
            '_ibm_bob_keycloak_url': 'https://bob-keycloak.apps.example.com',
            '_ibm_bob_keycloak_admin_user': 'temp-admin',
            '_ibm_bob_keycloak_admin_password': 'secretpassword',
            '_ibm_bob_rag_url': '',
            '_ibm_bob_internal_search_url': '',
            '_ibm_bob_z_proxy_url': '',
            '_ibm_bob_z_lookup_url': '',
            '_ibm_bob_self_signed_ca': True,
            '_ibm_bob_ca_cert_pem': 'CERTIFICATE',
            '_ibm_bob_ca_cert_file': '/path/to/bob-ca.crt'
        }
        rendered = self.template.render(context)
        self.assertIn('IBM Bob gateway URL: https://api.bob.apps.example.com', rendered)
        self.assertIn('IBM Bob admin UI: https://bob.apps.example.com', rendered)
        self.assertIn('Keycloak URL: https://bob-keycloak.apps.example.com', rendered)
        self.assertNotIn('RAG URL:', rendered)
        self.assertNotIn('Z Proxy URL:', rendered)
        self.assertIn('CA certificate: /path/to/bob-ca.crt', rendered)

    def test_info_rendering_with_premium_packages(self):
        context = {
            '_ibm_bob_gateway_url': 'https://api.bob.apps.example.com',
            '_ibm_bob_admin_ui_url': 'https://bob.apps.example.com',
            '_ibm_bob_keycloak_url': 'https://bob-keycloak.apps.example.com',
            '_ibm_bob_keycloak_admin_user': 'temp-admin',
            '_ibm_bob_keycloak_admin_password': 'secretpassword',
            '_ibm_bob_rag_url': 'https://bob-rag.ibm-bob.svc.cluster.local:8080',
            '_ibm_bob_internal_search_url': 'https://bob-search.ibm-bob.svc.cluster.local:8082',
            '_ibm_bob_z_proxy_url': 'https://bob-zproxy.ibm-bob.svc.cluster.local:8081',
            '_ibm_bob_z_lookup_url': 'https://bob-zproxy.ibm-bob.svc.cluster.local:8083',
            '_ibm_bob_self_signed_ca': False,
            '_ibm_bob_ca_cert_pem': '',
            '_ibm_bob_tls_secret_name': 'custom-cert'
        }
        rendered = self.template.render(context)
        self.assertIn('RAG URL: https://bob-rag.ibm-bob.svc.cluster.local:8080', rendered)
        self.assertIn('Internal search URL: https://bob-search.ibm-bob.svc.cluster.local:8082', rendered)
        self.assertIn('Z Proxy URL: https://bob-zproxy.ibm-bob.svc.cluster.local:8081', rendered)
        self.assertIn('Z Lookup URL: https://bob-zproxy.ibm-bob.svc.cluster.local:8083', rendered)
        self.assertIn('User-provided certificate in use (secret custom-cert)', rendered)

if __name__ == '__main__':
    unittest.main()
