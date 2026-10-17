"""
Unit tests for the ibm_bob preprocessor — no container, no cluster required.

Run from the repo root with:
    PYTHONPATH=automation-roles/10-validation/lint-config/scripts \
    python3 tests/ibm-bob/test_preprocessor.py

Or via the convenience wrapper:
    bash tests/ibm-bob/run_unit_tests.sh
"""

import sys, os, unittest

# Make the generatorPreProcessor helper importable from its source location
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__),
    '../../automation-roles/10-validation/lint-config/scripts'
))
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__),
    '../../automation-generators/generic/ibm_bob'
))

from preprocessor import preprocessor

# ---------------------------------------------------------------------------
# Minimal base config shared by all tests:
# A single openshift cluster with one storage entry.
# ---------------------------------------------------------------------------
BASE_OPENSHIFT = {
    'openshift': [
        {
            'name': 'pluto-01',
            'ocp_version': '4.20',
            'openshift_storage': [
                {'storage_name': 'odf-storage', 'storage_type': 'odf'}
            ]
        }
    ]
}

def _full_config(attrs):
    """Merge attrs into a full_config that also contains the ibm_bob list."""
    fc = dict(BASE_OPENSHIFT)
    fc['ibm_bob'] = [attrs]
    return fc

def _valid_base():
    return {
        'project': 'ibm-bob',
        'openshift_cluster_name': 'pluto-01',
        'openshift_storage_name': 'odf-storage',
        'ibm_bob_version': '2.0.0',
        'accept_licenses': True,
    }

def run(attrs, env=None):
    """Run the preprocessor with the given attrs dict and optional env vars."""
    saved = {}
    for k, v in (env or {}).items():
        saved[k] = os.environ.get(k)
        os.environ[k] = v
    try:
        result = preprocessor(
            attributes=attrs,
            fullConfig=_full_config(attrs),
            moduleVariables={}
        )
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    return result


def errors(result):
    return [e['message'] for e in result.get('errors', [])]


class TestValidConfigs(unittest.TestCase):

    def test_minimal_valid(self):
        r = run(_valid_base())
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_operators_project_defaulted(self):
        r = run(_valid_base())
        self.assertEqual(r['attributes_updated']['operators_project'], 'ibm-bob-operators')

    def test_state_defaulted(self):
        r = run(_valid_base())
        self.assertEqual(r['attributes_updated']['state'], 'installed')

    def test_latest_version_accepted(self):
        attrs = {**_valid_base(), 'ibm_bob_version': 'latest'}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_premium_packages_all_false(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': False, 'z_proxy': False, 'understand': False}}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_premium_packages_rag_only(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': True}}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_premium_packages_rag_and_zproxy(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': True, 'z_proxy': True}}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_accept_licenses_via_env(self):
        attrs = _valid_base()
        del attrs['accept_licenses']
        r = run(attrs, env={'CPD_ACCEPT_LICENSES': 'true', 'ACTION': 'apply'})
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_explicit_operators_project(self):
        attrs = {**_valid_base(), 'operators_project': 'bob-ops'}
        r = run(attrs)
        self.assertEqual(r['attributes_updated']['operators_project'], 'bob-ops')

    def test_state_installed_explicit(self):
        attrs = {**_valid_base(), 'state': 'installed'}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_reuse_existing_cert_manager_true(self):
        attrs = {**_valid_base(), 'reuse_existing_cert_manager': True}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_reuse_existing_cert_manager_false(self):
        attrs = {**_valid_base(), 'reuse_existing_cert_manager': False}
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_reuse_existing_cert_manager_not_defaulted_to_true(self):
        r = run(_valid_base())
        self.assertNotEqual(r['attributes_updated'].get('reuse_existing_cert_manager'), True)


class TestInvalidConfigs(unittest.TestCase):

    def test_missing_project(self):
        attrs = {k: v for k, v in _valid_base().items() if k != 'project'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('project' in m.lower() for m in msgs), msgs)

    def test_missing_version(self):
        attrs = {k: v for k, v in _valid_base().items() if k != 'ibm_bob_version'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('ibm_bob_version' in m.lower() for m in msgs), msgs)

    def test_bad_version_format(self):
        attrs = {**_valid_base(), 'ibm_bob_version': '2-0-0'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('x.y.z' in m or 'format' in m for m in msgs), msgs)

    def test_bad_version_format_two_parts(self):
        attrs = {**_valid_base(), 'ibm_bob_version': '2.0'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('x.y.z' in m or 'format' in m for m in msgs), msgs)

    def test_license_not_accepted(self):
        attrs = {k: v for k, v in _valid_base().items() if k != 'accept_licenses'}
        r = run(attrs, env={'CPD_ACCEPT_LICENSES': '', 'ACTION': 'apply'})
        msgs = errors(r)
        self.assertTrue(any('accept_licenses' in m or 'license' in m.lower() for m in msgs), msgs)

    def test_state_removed_allowed(self):
        """state: removed must now pass validation (no license, no storage check)."""
        # Minimal attrs for removal: no accept_licenses, no openshift_storage_name needed
        attrs = {
            'project': 'ibm-bob',
            'openshift_cluster_name': 'pluto-01',
            'ibm_bob_version': '2.0.0',
            'state': 'removed',
        }
        r = run(attrs)
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_state_removed_no_license_required(self):
        """state: removed must not require accept_licenses."""
        attrs = {
            'project': 'ibm-bob',
            'openshift_cluster_name': 'pluto-01',
            'ibm_bob_version': '2.0.0',
            'state': 'removed',
            # deliberately omit accept_licenses
        }
        r = run(attrs, env={'CPD_ACCEPT_LICENSES': '', 'ACTION': 'apply'})
        msgs = errors(r)
        self.assertFalse(any('license' in m.lower() or 'accept_licenses' in m for m in msgs), msgs)

    def test_state_removed_no_storage_required(self):
        """state: removed must not require openshift_storage_name to be valid."""
        attrs = {
            'project': 'ibm-bob',
            'openshift_cluster_name': 'pluto-01',
            'ibm_bob_version': '2.0.0',
            'state': 'removed',
            # deliberately omit openshift_storage_name
        }
        r = run(attrs)
        msgs = errors(r)
        self.assertFalse(any('storage' in m.lower() for m in msgs), msgs)

    def test_state_invalid(self):
        """A state other than installed or removed must be rejected."""
        attrs = {**_valid_base(), 'state': 'paused'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('paused' in m or 'is not one of' in m for m in msgs), msgs)

    def test_zproxy_without_rag(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': False, 'z_proxy': True}}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('z_proxy' in m or 'rag' in m for m in msgs), msgs)

    def test_unknown_premium_package(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': False, 'turbo_mode': True}}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('turbo_mode' in m or 'unknown' in m.lower() for m in msgs), msgs)

    def test_reuse_existing_cert_manager_non_boolean(self):
        attrs = {**_valid_base(), 'reuse_existing_cert_manager': 'yes'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('is not one of' in m for m in msgs), msgs)

    def test_premium_package_non_boolean(self):
        attrs = {**_valid_base(), 'premium_packages': {'rag': 'yes'}}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('True or False' in m or 'bool' in m.lower() for m in msgs), msgs)

    def test_airgap_requires_image_registry_name(self):
        attrs = _valid_base()
        r = run(attrs, env={'CPD_AIRGAP': 'true'})
        msgs = errors(r)
        self.assertTrue(any('image_registry_name' in m for m in msgs), msgs)

    def test_airgap_passes_with_image_registry_name(self):
        attrs = {**_valid_base(), 'image_registry_name': 'my-registry.example.com'}
        r = run(attrs, env={'CPD_AIRGAP': 'true'})
        # Should not error on the registry check (other checks must still pass)
        msgs = errors(r)
        self.assertFalse(any('image_registry_name' in m for m in msgs), msgs)

    def test_wrong_cluster_name(self):
        attrs = {**_valid_base(), 'openshift_cluster_name': 'does-not-exist'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('does-not-exist' in m for m in msgs), msgs)

    def test_wrong_storage_name(self):
        attrs = {**_valid_base(), 'openshift_storage_name': 'no-such-storage'}
        r = run(attrs)
        msgs = errors(r)
        self.assertTrue(any('no-such-storage' in m or 'openshift_storage' in m for m in msgs), msgs)


def _gateway(api_key='env.AZURE_API_KEY'):
    return {
        'models': [
            {'model_name': 'premium-ide',
             'openai_compatible': {'model': 'gpt-5.6-sol', 'base_url': 'https://x', 'api_key': api_key}},
        ],
        'routers': [{'name': 'router', 'strategy': 'static', 'static': {'default_model': 'premium-ide'}}],
    }


class TestModelGateway(unittest.TestCase):

    def test_gateway_with_secret_names_valid(self):
        attrs = {**_valid_base(), 'model_gateway': _gateway(),
                 'model_gateway_secret_names': {'AZURE_API_KEY': 'ibm-bob-azure-api-key'}}
        self.assertEqual(errors(run(attrs)), [])

    def test_gateway_without_secrets_valid(self):
        attrs = {**_valid_base(), 'model_gateway': _gateway(api_key='plain-value')}
        self.assertEqual(errors(run(attrs)), [])

    def test_env_reference_without_secret_name(self):
        attrs = {**_valid_base(), 'model_gateway': _gateway()}
        msgs = errors(run(attrs))
        self.assertTrue(any('env.AZURE_API_KEY' in m for m in msgs), msgs)

    def test_env_reference_in_x_providers_ignored(self):
        gw = _gateway(api_key='plain-value')
        gw['x-providers'] = {'azure': {'openai_compatible': {'api_key': 'env.UNUSED'}}}
        attrs = {**_valid_base(), 'model_gateway': gw}
        self.assertEqual(errors(run(attrs)), [])

    def test_secret_names_without_gateway(self):
        attrs = {**_valid_base(), 'model_gateway_secret_names': {'AZURE_API_KEY': 'x'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('together with model_gateway' in m for m in msgs), msgs)

    def test_secret_names_must_be_strings(self):
        attrs = {**_valid_base(), 'model_gateway': _gateway(),
                 'model_gateway_secret_names': {'AZURE_API_KEY': ''}}
        msgs = errors(run(attrs))
        self.assertTrue(any('vault secret names' in m for m in msgs), msgs)

    def test_gateway_must_be_dict(self):
        attrs = {**_valid_base(), 'model_gateway': 'path/to/file.yaml'}
        msgs = errors(run(attrs))
        self.assertTrue(any('model_gateway must be a dictionary' in m for m in msgs), msgs)


class TestOpenShiftAIModels(unittest.TestCase):
    """Tests for the openshift_ai_models validation block."""

    def _ai_base(self):
        """Minimal valid openshift_ai_models block."""
        return {'core_model': 'nemotron-3-ultra'}

    def test_valid_nemotron_fp8(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'quantization': 'fp8'}}
        self.assertEqual(errors(run(attrs)), [])

    def test_valid_laguna_nvfp4(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'laguna-s-2.1', 'quantization': 'nvfp4'}}
        self.assertEqual(errors(run(attrs)), [])

    def test_valid_mistral_fp8(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'mistral-medium-3.5', 'quantization': 'fp8'}}
        self.assertEqual(errors(run(attrs)), [])

    def test_default_quantization_accepted(self):
        """quantization defaults to fp8; omitting it must be valid."""
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra'}}
        self.assertEqual(errors(run(attrs)), [])

    def test_valid_with_optional_fields(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {
            'core_model': 'nemotron-3-ultra',
            'quantization': 'fp8',
            'guardrail_model': 'openai/gpt-oss-20b',
            'project': 'ibm-bob-models',
            'gpus_per_core_model': 8,
            'gpus_per_guardrail_model': 1,
            'storage_size': {'core': '700Gi', 'guardrail': '60Gi'},
            'huggingface_token_secret_name': 'ibm-bob-hf-token',
            'vllm_extra_args': ['--max-num-seqs=128'],
            'skip_gpu_check': False,
        }}
        self.assertEqual(errors(run(attrs)), [])

    def test_skip_gpu_check_true(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {
            'core_model': 'nemotron-3-ultra',
            'skip_gpu_check': True,
        }}
        self.assertEqual(errors(run(attrs)), [])

    # --- mutual exclusion ---

    def test_mutually_exclusive_with_model_gateway(self):
        gw = {
            'models': [{'model_name': 'premium-ide', 'openai_compatible': {'base_url': 'http://x', 'model': 'm'}}],
            'routers': [{'name': 'r', 'strategy': 'static', 'static': {'default_model': 'premium-ide'}}],
        }
        attrs = {**_valid_base(),
                 'model_gateway': gw,
                 'openshift_ai_models': {'core_model': 'nemotron-3-ultra'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('mutually exclusive' in m for m in msgs), msgs)

    def test_mutually_exclusive_with_model_gateway_secret_names(self):
        gw = {
            'models': [{'model_name': 'premium-ide', 'openai_compatible': {'base_url': 'http://x', 'model': 'm'}}],
            'routers': [{'name': 'r', 'strategy': 'static', 'static': {'default_model': 'premium-ide'}}],
        }
        attrs = {**_valid_base(),
                 'model_gateway': gw,
                 'model_gateway_secret_names': {'K': 'v'},
                 'openshift_ai_models': {'core_model': 'nemotron-3-ultra'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('mutually exclusive' in m for m in msgs), msgs)

    # --- core_model ---

    def test_missing_core_model(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'quantization': 'fp8'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('core_model' in m for m in msgs), msgs)

    def test_unknown_core_model(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'gpt-999'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('gpt-999' in m or 'not supported' in m for m in msgs), msgs)

    def test_mistral_nvfp4_rejected(self):
        """mistral-medium-3.5 does not support nvfp4."""
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'mistral-medium-3.5', 'quantization': 'nvfp4'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('nvfp4' in m or 'quantization' in m for m in msgs), msgs)

    def test_unknown_quantization(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'quantization': 'int8'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('int8' in m or 'quantization' in m for m in msgs), msgs)

    # --- type checks ---

    def test_not_a_dict(self):
        attrs = {**_valid_base(), 'openshift_ai_models': 'nemotron-3-ultra'}
        msgs = errors(run(attrs))
        self.assertTrue(any('dictionary' in m for m in msgs), msgs)

    def test_gpus_per_core_model_must_be_int(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'gpus_per_core_model': '8'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('gpus_per_core_model' in m and 'integer' in m for m in msgs), msgs)

    def test_storage_size_must_be_dict(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'storage_size': '700Gi'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('storage_size' in m and 'dictionary' in m for m in msgs), msgs)

    def test_storage_size_unknown_key(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'storage_size': {'main': '700Gi'}}}
        msgs = errors(run(attrs))
        self.assertTrue(any('main' in m for m in msgs), msgs)

    def test_storage_size_values_must_be_strings(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'storage_size': {'core': 700}}}
        msgs = errors(run(attrs))
        self.assertTrue(any('storage_size' in m for m in msgs), msgs)

    def test_vllm_extra_args_must_be_list_of_strings(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'vllm_extra_args': '--flag'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('vllm_extra_args' in m for m in msgs), msgs)

    def test_skip_gpu_check_must_be_bool(self):
        attrs = {**_valid_base(), 'openshift_ai_models': {'core_model': 'nemotron-3-ultra', 'skip_gpu_check': 'true'}}
        msgs = errors(run(attrs))
        self.assertTrue(any('skip_gpu_check' in m for m in msgs), msgs)

    # --- air-gapped ---

    def test_hf_token_allowed_in_connected(self):
        """huggingface_token_secret_name must be accepted in connected mode."""
        attrs = {**_valid_base(), 'openshift_ai_models': {
            'core_model': 'nemotron-3-ultra',
            'huggingface_token_secret_name': 'my-hf-secret',
        }}
        msgs = errors(run(attrs))
        self.assertFalse(any('huggingface_token_secret_name' in m for m in msgs), msgs)

    def test_hf_token_allowed_in_airgap(self):
        """huggingface_token_secret_name is also valid in air-gapped mode.
        It is used during env download (connected side) to pull gated model weights
        into status_dir; the deployer uploads them to the PVC at apply time."""
        attrs = {**_valid_base(),
                 'image_registry_name': 'bob-mirror',
                 'openshift_ai_models': {
                     'core_model': 'nemotron-3-ultra',
                     'huggingface_token_secret_name': 'my-hf-secret',
                 }}
        msgs = errors(run(attrs, env={'CPD_AIRGAP': 'true'}))
        self.assertFalse(any('huggingface_token_secret_name' in m for m in msgs), msgs)


class TestSampleConfigs(unittest.TestCase):
    """The shipped sample configs, combined with ocp-existing-ocp.yaml, must pass."""

    SAMPLES_DIR = os.path.join(
        os.path.dirname(__file__),
        '../../sample-configurations/sample-dynamic/config-samples'
    )

    def _load(self, name):
        import yaml
        with open(os.path.join(self.SAMPLES_DIR, name)) as f:
            # The deployer templates {{ env_id }} before the preprocessor runs
            return yaml.safe_load(f.read().replace('{{ env_id }}', 'pluto-01'))

    def _check_sample(self, name):
        full = self._load('ocp-existing-ocp.yaml')
        full.update(self._load(name))
        attrs = full['ibm_bob'][0]
        r = preprocessor(attributes=attrs, fullConfig=full, moduleVariables={})
        self.assertEqual(errors(r), [], msg=errors(r))

    def test_sample_200(self):
        self._check_sample('ibm-bob-200.yaml')

    def test_sample_latest(self):
        self._check_sample('ibm-bob-latest.yaml')

    def test_sample_airgap_image_registry_name(self):
        """ibm-bob-200.yaml with image_registry_name set must pass when CPD_AIRGAP is true."""
        full = self._load('ocp-existing-ocp.yaml')
        full.update(self._load('ibm-bob-200.yaml'))
        attrs = full['ibm_bob'][0]
        attrs['image_registry_name'] = 'bob-mirror'
        r = preprocessor(attributes=attrs, fullConfig=full, moduleVariables={'cpd_airgap': 'true'})
        self.assertEqual(errors(r), [], msg=errors(r))


if __name__ == '__main__':
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
