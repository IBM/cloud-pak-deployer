"""
Tests for ibm-bob-variables version resolution logic, version definition files,
and vLLM image path derivation for air-gapped installs.
"""

import sys, os, re, ast, unittest, glob, yaml, json, jinja2

VERSIONS_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-variables/vars/versions'
)

MODELS_FILE = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-variables/vars/ibm-bob-models.yml'
)

# Variables that used to be in the version files and that no role uses
REMOVED_VERSION_KEYS = ('_ibm_bob_release_tag', '_ibm_bob_companion_versions', '_ibm_bob_premium_package_keys')


class TestIbmBobVersions(unittest.TestCase):

    def test_version_files_exist(self):
        files = glob.glob(os.path.join(VERSIONS_DIR, '*.yml'))
        self.assertGreater(len(files), 0, "No version definition files found")

    def test_200_version_file_content(self):
        v200_file = os.path.join(VERSIONS_DIR, '2.0.0.yml')
        self.assertTrue(os.path.exists(v200_file), "2.0.0.yml does not exist")
        with open(v200_file, 'r') as f:
            data = yaml.safe_load(f)

        # the only per-version data is the list of supported OpenShift versions
        self.assertEqual(list(data), ['_ibm_bob_supported_ocp_versions'])
        self.assertEqual(data['_ibm_bob_supported_ocp_versions'], ['4.20', '4.21', '4.22'])

    def test_201_version_file_content(self):
        v201_file = os.path.join(VERSIONS_DIR, '2.0.1.yml')
        self.assertTrue(os.path.exists(v201_file), "2.0.1.yml does not exist")
        with open(v201_file, 'r') as f:
            data = yaml.safe_load(f)
        self.assertEqual(list(data), ['_ibm_bob_supported_ocp_versions'])
        self.assertEqual(data['_ibm_bob_supported_ocp_versions'], ['4.20', '4.21', '4.22'])

    def test_version_files_hold_no_deployer_data(self):
        for path in glob.glob(os.path.join(VERSIONS_DIR, '*.yml')):
            with open(path) as f:
                data = yaml.safe_load(f)
            self.assertEqual(list(data), ['_ibm_bob_supported_ocp_versions'], path)
            for key in REMOVED_VERSION_KEYS:
                self.assertNotIn(key, data, path)

    def test_version_file_names_are_versions(self):
        for path in glob.glob(os.path.join(VERSIONS_DIR, '*.yml')):
            self.assertRegex(os.path.basename(path), r'^\d+\.\d+\.\d+\.yml$')

    def test_models_file_holds_version_independent_data(self):
        with open(MODELS_FILE) as f:
            data = yaml.safe_load(f)
        for key in ('_ibm_bob_ai_models', '_ibm_bob_vllm_runtime_image', '_ibm_bob_loader_image',
                    '_ibm_bob_guardrail_model_defaults'):
            self.assertIn(key, data)
        self.assertNotIn('_ibm_bob_supported_ocp_versions', data)
        for key in REMOVED_VERSION_KEYS:
            self.assertNotIn(key, data)


class TestIbmBobAiModelsTable(unittest.TestCase):
    """The model table in ibm-bob-models.yml must agree with CORE_MODELS in the preprocessor."""

    EXPECTED_REPOS = {
        ('mistral-medium-3.5', 'fp8'): 'mistralai/Mistral-Medium-3.5-128B',
        ('nemotron-3-ultra', 'fp8'): 'RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-FP8-dynamic',
        ('nemotron-3-ultra', 'nvfp4'): 'RedHatAI/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4',
        ('nemotron-3.5-super', 'nvfp4'): 'nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4',
        ('laguna-s-2.1', 'fp8'): 'poolside/Laguna-S-2.1-FP8',
        ('laguna-s-2.1', 'nvfp4'): 'poolside/Laguna-S-2.1-NVFP4',
    }

    def setUp(self):
        sys.path.insert(0, os.path.join(
            os.path.dirname(__file__), '../../../automation-roles/10-validation/lint-config/scripts'))
        sys.path.insert(0, os.path.join(
            os.path.dirname(__file__), '../../../automation-generators/generic/ibm_bob'))
        from preprocessor import CORE_MODELS
        self.core_models = CORE_MODELS
        with open(MODELS_FILE, 'r') as f:
            self.models = {m['id']: m for m in yaml.safe_load(f)['_ibm_bob_ai_models']}

    def test_models_and_quantizations_match_preprocessor(self):
        self.assertEqual(set(self.models), set(self.core_models))
        for model_id, quants in self.core_models.items():
            self.assertEqual(list(self.models[model_id]['quantizations']), quants, model_id)
            # first quantization in CORE_MODELS is the default
            self.assertEqual(self.models[model_id]['default_quantization'], quants[0], model_id)

    def test_repositories_and_draft_models(self):
        found = {}
        for model_id, model in self.models.items():
            for quant, qdef in model['quantizations'].items():
                self.assertTrue(qdef['hf_repo'], (model_id, quant))
                self.assertTrue(qdef['default_storage'], (model_id, quant))
                found[(model_id, quant)] = qdef['hf_repo']
                # a draft repo and its directory are either both set or both empty
                self.assertEqual(bool(qdef.get('draft_hf_repo')), bool(qdef.get('draft_model_dir')), (model_id, quant))
                if qdef.get('draft_model_dir'):
                    self.assertTrue(
                        any('/mnt/models/' + qdef['draft_model_dir'] in a for a in qdef.get('vllm_args', [])),
                        (model_id, quant))
        self.assertEqual(found, self.EXPECTED_REPOS)

    def test_no_obsolete_fields(self):
        for model_id, model in self.models.items():
            for field in ('z_only', 'hf_repo', 'hf_repo_nvfp4', 'draft_hf_repo', 'draft_model_dir', 'default_storage'):
                self.assertNotIn(field, model, (model_id, field))
            # tensor-parallel size is generated from the GPU count
            self.assertFalse(any(a.startswith('--tensor-parallel-size') for a in model['vllm_args']), model_id)
            self.assertNotIn('runtime_image', model, model_id)

    def test_single_vllm_runtime_image(self):
        with open(MODELS_FILE, 'r') as f:
            data = yaml.safe_load(f)
        self.assertTrue(data['_ibm_bob_vllm_runtime_image'].startswith('vllm/vllm-openai:v'))
        self.assertNotIn('runtime_image', data['_ibm_bob_guardrail_model_defaults'])
        for model in data['_ibm_bob_ai_models']:
            self.assertFalse(any('--disable-log-requests' in a for a in model['vllm_args']), model['id'])
        self.assertFalse(any('--disable-log-requests' in a for a in data['_ibm_bob_guardrail_model_defaults']['vllm_args']))

    def test_loader_image_defined(self):
        with open(MODELS_FILE, 'r') as f:
            data = yaml.safe_load(f)
        self.assertEqual(data['_ibm_bob_loader_image'], 'registry.access.redhat.com/ubi9/ubi:latest')

    def test_supports_vision(self):
        self.assertTrue(self.models['nemotron-3.5-super']['supports_vision'])
        for model_id in ('nemotron-3-ultra', 'laguna-s-2.1'):
            self.assertFalse(self.models[model_id]['supports_vision'], model_id)


TASKS_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-variables/tasks'
)


def _find_task(tasks, name_prefix):
    """Depth-first search of an Ansible task list (including block/rescue) by task name prefix."""
    for task in tasks:
        if task.get('name', '').startswith(name_prefix):
            return task
        for key in ('block', 'rescue', 'always'):
            if key in task:
                found = _find_task(task[key], name_prefix)
                if found:
                    return found
    return None


def _render(task_file, task_name, fact, **variables):
    """Render the Jinja expression of a set_fact task, taken from the real task file.
    Ansible-only filters and tests used by these expressions are stubbed."""
    with open(os.path.join(TASKS_DIR, task_file)) as f:
        task = _find_task(yaml.safe_load(f), task_name)
    env = jinja2.Environment()
    env.filters['regex_replace'] = lambda s, p, r='': re.sub(p, r, s)
    env.filters['dirname'] = os.path.dirname
    env.filters['basename'] = os.path.basename
    env.filters['unique'] = lambda seq: list(dict.fromkeys(seq))
    env.tests['match'] = lambda s, p: re.match(p, s) is not None
    return env.from_string(task['set_fact'][fact]).render(**variables).strip()


class TestIbmBobBundleLookup(unittest.TestCase):
    """The bundle is resolved from the GitHub release, not from the version file."""

    def test_highest_version_is_numeric_not_alphabetical(self):
        candidates = ['2.0.2', '2.0.10', '2.0.9', '1.9.0']
        res = _render('resolve-version.yml', 'Determine highest IBM Bob version',
                      '_p_effective_bob_version', _ibm_bob_latest_candidates=candidates)
        self.assertEqual(res, '2.0.10')

    def test_newer_minor_wins_over_later_fixpack_of_older_minor(self):
        candidates = ['2.0.1', '2.1.0', '2.0.2']
        res = _render('resolve-version.yml', 'Determine highest IBM Bob version',
                      '_p_effective_bob_version', _ibm_bob_latest_candidates=candidates)
        self.assertEqual(res, '2.1.0')

    def test_candidates_from_releases_skip_drafts_prereleases_and_odd_tags(self):
        releases = [
            {'tag_name': 'v2.0.1', 'draft': False, 'prerelease': False},
            {'tag_name': 'v2.1.0', 'draft': False, 'prerelease': True},
            {'tag_name': 'v2.2.0', 'draft': True, 'prerelease': False},
            {'tag_name': 'v2.0.0', 'draft': False, 'prerelease': False},
            {'tag_name': 'nightly', 'draft': False, 'prerelease': False},
            {'tag_name': 'v2.0.1-rc1', 'draft': False, 'prerelease': False},
        ]
        res = _render('resolve-version.yml', 'Collect candidate versions from published releases',
                      '_ibm_bob_latest_candidates', _ibm_bob_releases={'json': releases})
        self.assertEqual(sorted(ast.literal_eval(res)), ['2.0.0', '2.0.1'])

    def test_air_gapped_candidates_come_from_cached_bundle_directories(self):
        files = [{'path': '/s/downloads/ibm-bob/2.0.1/ibm-bob-install-20261110-064941.tgz'},
                 {'path': '/s/downloads/ibm-bob/2.0.0/ibm-bob-install-20260924-163534.tgz'},
                 {'path': '/s/downloads/ibm-bob/models/x/ibm-bob-install-1.tgz'}]
        res = _render('resolve-version.yml', 'Collect candidate versions from downloaded bundles',
                      '_ibm_bob_latest_candidates', _ibm_bob_cached_bundles={'files': files})
        self.assertEqual(sorted(ast.literal_eval(res)), ['2.0.0', '2.0.1'])

    def test_bundle_asset_regex_and_digest_check(self):
        with open(os.path.join(TASKS_DIR, 'resolve-bundle.yml')) as f:
            tasks = yaml.safe_load(f)
        sel = _find_task(tasks, 'Select IBM Bob release bundle asset')['set_fact']['_ibm_bob_release_assets']
        self.assertIn(r"^ibm-bob-install-.*\.tgz$", sel)
        digest_task = _find_task(tasks, 'Fail if the release bundle asset has no sha256 digest')
        self.assertIn("^sha256:[0-9a-f]{64}$", digest_task['when'])

    def test_no_bundle_properties_pinned_in_version_files(self):
        for path in glob.glob(os.path.join(VERSIONS_DIR, '*.yml')):
            with open(path) as f:
                data = yaml.safe_load(f)
            for key in ('_ibm_bob_bundle_filename', '_ibm_bob_bundle_url', '_ibm_bob_bundle_sha256'):
                self.assertNotIn(key, data, path)


class TestVllmImagePathDerivation(unittest.TestCase):
    """
    Tests for the Jinja path derivation logic implemented in ibm-bob-variables/tasks/main.yml.
    Verifies that default, overridden, external and already-private container image
    references derive the correct destination paths and effective ServingRuntime images.
    """

    DERIVATION_TEMPLATE = """
    {%- set reg_host = pull_prefix.split('/')[0] -%}
    {%- set first_seg = raw_image.split('/')[0] -%}
    {%- set repo = raw_image.split('/', 1)[1] if ('/' in raw_image and ('.' in first_seg or ':' in first_seg or first_seg == 'localhost')) else raw_image -%}
    {%- set is_private = is_airgap and (raw_image.startswith(pull_prefix) or first_seg == reg_host) -%}
    {%- set effective = raw_image if (not is_airgap or is_private) else (pull_prefix ~ '/' ~ repo) -%}
    {"repo": "{{ repo }}", "is_private": {{ "true" if is_private else "false" }}, "effective": "{{ effective }}"}
    """

    def derive(self, raw_image, pull_prefix="icr.io", is_airgap=False):
        env = jinja2.Environment()
        res = env.from_string(self.DERIVATION_TEMPLATE).render(
            raw_image=raw_image,
            pull_prefix=pull_prefix,
            is_airgap=is_airgap
        )
        return json.loads(res.strip())

    def test_default_image_connected(self):
        """In connected mode, default upstream image is returned as-is."""
        res = self.derive("vllm/vllm-openai:v0.32.0", pull_prefix="icr.io", is_airgap=False)
        self.assertEqual(res["effective"], "vllm/vllm-openai:v0.32.0")
        self.assertEqual(res["repo"], "vllm/vllm-openai:v0.32.0")
        self.assertFalse(res["is_private"])

    def test_default_image_airgap_with_prefix(self):
        """In air-gapped mode with a registry namespace prefix, dest path is prefixed."""
        res = self.derive("vllm/vllm-openai:v0.32.0", pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["effective"], "myreg.corp.com:5000/cp4d/vllm/vllm-openai:v0.32.0")
        self.assertEqual(res["repo"], "vllm/vllm-openai:v0.32.0")
        self.assertFalse(res["is_private"])

    def test_default_image_airgap_without_prefix(self):
        """In air-gapped mode without a registry namespace prefix, dest path uses registry host."""
        res = self.derive("vllm/vllm-openai:v0.32.0", pull_prefix="myreg.corp.com:5000", is_airgap=True)
        self.assertEqual(res["effective"], "myreg.corp.com:5000/vllm/vllm-openai:v0.32.0")
        self.assertEqual(res["repo"], "vllm/vllm-openai:v0.32.0")
        self.assertFalse(res["is_private"])

    def test_docker_io_explicit_prefix_airgap(self):
        """docker.io/ prefix is stripped when deriving the private registry destination."""
        res = self.derive("docker.io/vllm/vllm-openai:v0.32.0", pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["effective"], "myreg.corp.com:5000/cp4d/vllm/vllm-openai:v0.32.0")
        self.assertEqual(res["repo"], "vllm/vllm-openai:v0.32.0")
        self.assertFalse(res["is_private"])

    def test_overridden_external_registry_airgap(self):
        """External registry host (e.g. quay.io) is stripped and prefixed with private registry."""
        res = self.derive("quay.io/custom-org/my-vllm:v1.0", pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["effective"], "myreg.corp.com:5000/cp4d/custom-org/my-vllm:v1.0")
        self.assertEqual(res["repo"], "custom-org/my-vllm:v1.0")
        self.assertFalse(res["is_private"])

    def test_already_in_private_registry_matching_prefix(self):
        """Image reference already starting with the exact pull prefix is recognized as private."""
        img = "myreg.corp.com:5000/cp4d/vllm/vllm-openai:v0.32.0"
        res = self.derive(img, pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["effective"], img)
        self.assertTrue(res["is_private"])

    def test_loader_image_airgap(self):
        """The ubi9 loader image is mirrored to the private registry and pulled from there."""
        res = self.derive("registry.access.redhat.com/ubi9/ubi:latest", pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["repo"], "ubi9/ubi:latest")
        self.assertEqual(res["effective"], "myreg.corp.com:5000/cp4d/ubi9/ubi:latest")
        self.assertFalse(res["is_private"])

    def test_loader_image_connected(self):
        """In connected mode the loader image is used as-is."""
        res = self.derive("registry.access.redhat.com/ubi9/ubi:latest", pull_prefix="icr.io", is_airgap=False)
        self.assertEqual(res["effective"], "registry.access.redhat.com/ubi9/ubi:latest")

    def test_already_in_private_registry_matching_host(self):
        """Image reference on the private registry host (different path) is preserved."""
        img = "myreg.corp.com:5000/pre-mirrored/vllm:v1.0"
        res = self.derive(img, pull_prefix="myreg.corp.com:5000/cp4d", is_airgap=True)
        self.assertEqual(res["effective"], img)
        self.assertTrue(res["is_private"])


if __name__ == '__main__':
    unittest.main()
