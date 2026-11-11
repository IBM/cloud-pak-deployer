"""
Tests for the IBM Bob upgrade detection and the upgrade flow in ibm-bob-cluster:
check-bob-upgrade.yml, upgrade-bob.yml, install-bob.yml and wait-for-ready.yml.

The Jinja expressions are taken from the real task files and rendered with the
Ansible-only filters and tests stubbed.
"""

import os, re, unittest, yaml
from jinja2.nativetypes import NativeEnvironment

TASKS_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-cluster/tasks'
)


def _load(name):
    with open(os.path.join(TASKS_DIR, name)) as f:
        return yaml.safe_load(f)


def _find_task(tasks, name_prefix):
    for task in tasks:
        if task.get('name', '').startswith(name_prefix):
            return task
    return None


def _vkey(v):
    return tuple(int(p) for p in str(v).split('.'))


def _env():
    env = NativeEnvironment()
    env.filters['bool'] = lambda v: v if isinstance(v, bool) else str(v).lower() in ('true', 'yes', '1')
    env.filters['regex_replace'] = lambda s, p, r='': re.sub(p, r, s)
    env.tests['match'] = lambda s, p: re.match(p, s) is not None
    env.tests['version'] = lambda a, b, op='eq': {
        '<': _vkey(a) < _vkey(b), '>': _vkey(a) > _vkey(b), '==': _vkey(a) == _vkey(b)}[op]
    return env


def _render_task(task, **context):
    """Render the task's vars (in order) and set_fact values, return the set_fact dict."""
    env = _env()
    ctx = dict(context)
    for key, expr in (task.get('vars') or {}).items():
        ctx[key] = env.from_string(expr).render(**ctx) if isinstance(expr, str) else expr
    out = {}
    for key, expr in task['set_fact'].items():
        value = env.from_string(expr).render(**ctx) if isinstance(expr, str) else expr
        out[key] = value.strip() if isinstance(value, str) else value
    return out


def detect(installed_cr, requested):
    """Run the two set_fact tasks of check-bob-upgrade.yml and return (installed, action)."""
    tasks = _load('check-bob-upgrade.yml')
    resources = [] if installed_cr is None else [installed_cr]
    facts = _render_task(
        _find_task(tasks, 'Determine installed IBM Bob version'),
        _ibm_bob_current_cr={'resources': resources})
    facts.update(_render_task(
        _find_task(tasks, 'Determine IBM Bob action'),
        _ibm_bob_version=requested, **facts))
    return facts['_ibm_bob_installed_version'], facts['_ibm_bob_action']


def cr(spec_version=None, label=None):
    res = {'metadata': {}, 'spec': {}}
    if spec_version is not None:
        res['spec']['version'] = spec_version
    if label is not None:
        res['metadata']['labels'] = {'app.kubernetes.io/version': label}
    return res


class TestBobUpgradeDetection(unittest.TestCase):

    def test_no_cr_is_fresh_install(self):
        self.assertEqual(detect(None, '2.0.1'), ('', 'install'))

    def test_older_version_is_upgrade(self):
        self.assertEqual(detect(cr('2.0.0'), '2.0.1'), ('2.0.0', 'upgrade'))

    def test_same_version_is_reapply(self):
        self.assertEqual(detect(cr('2.0.1'), '2.0.1'), ('2.0.1', 'reapply'))

    def test_newer_installed_version_is_downgrade(self):
        self.assertEqual(detect(cr('2.0.1'), '2.0.0'), ('2.0.1', 'downgrade'))

    def test_comparison_is_numeric_not_alphabetical(self):
        self.assertEqual(detect(cr('2.0.9'), '2.0.10')[1], 'upgrade')
        self.assertEqual(detect(cr('2.0.10'), '2.0.9')[1], 'downgrade')

    def test_label_is_used_when_spec_version_is_missing(self):
        self.assertEqual(detect(cr(label='2.0.0-3'), '2.0.1'), ('2.0.0', 'upgrade'))

    def test_spec_version_wins_over_label(self):
        self.assertEqual(detect(cr('2.0.1', label='2.0.0-3'), '2.0.1'), ('2.0.1', 'reapply'))

    def test_unknown_version_falls_back_to_install(self):
        self.assertEqual(detect(cr(), '2.0.1'), ('', 'install'))
        self.assertEqual(detect(cr('garbage'), '2.0.1'), ('', 'install'))

    def test_downgrade_fails_and_unknown_version_warns(self):
        tasks = _load('check-bob-upgrade.yml')
        fail = _find_task(tasks, 'Fail if the requested IBM Bob version is lower')
        self.assertEqual(fail['when'], "_ibm_bob_action == 'downgrade'")
        self.assertIn('fail', fail)
        warn = _find_task(tasks, 'Warn when the installed IBM Bob version cannot be determined')
        self.assertIn('debug', warn)

    def test_detection_only_reads_the_cluster(self):
        # it also runs in dry-run mode, so it must not change anything
        for task in _load('check-bob-upgrade.yml'):
            modules = set(task) & {'kubernetes.core.k8s', 'shell', 'command', 'include_role'}
            self.assertEqual(modules, set(), task.get('name'))

    def test_main_calls_detection_before_any_cluster_change(self):
        names = [t.get('name', '') for t in _load('main.yml')]
        detect_idx = next(i for i, n in enumerate(names) if 'installed, re-applied or upgraded' in n)
        airgap_idx = next(i for i, n in enumerate(names) if n.startswith('Perform air-gapped pre-install'))
        install_idx = next(i for i, n in enumerate(names) if n.startswith('Install IBM Bob'))
        self.assertLess(detect_idx, airgap_idx)
        self.assertLess(airgap_idx, install_idx)


class TestBobUpgradeFlow(unittest.TestCase):

    def test_install_bob_branches_on_upgrade(self):
        tasks = _load('install-bob.yml')
        install = _find_task(tasks, 'Run bobctl install')
        self.assertIn('_upgrade_bob', install['when'])
        self.assertIn('--accept-license', install['vars']['_p_command'])
        upgrade = _find_task(tasks, 'Upgrade IBM Bob')
        self.assertEqual(upgrade['include_tasks'], 'upgrade-bob.yml')
        # the cluster-scoped resources are generated and applied on both paths, before the branch
        names = [t.get('name', '') for t in tasks]
        branch = names.index(install['name'])
        self.assertLess(next(i for i, n in enumerate(names) if n.startswith('Generate cluster-scoped')), branch)
        self.assertLess(next(i for i, n in enumerate(names) if n.startswith('Apply IBM Bob cluster-scoped')), branch)

    def test_upgrade_runs_bobctl_upgrade_without_flags(self):
        cmd = _find_task(_load('upgrade-bob.yml'), 'Run bobctl upgrade')['vars']['_p_command']
        self.assertTrue(cmd.rstrip().endswith('upgrade'))
        for flag in ('--accept-license', '--registry-creds', '--model-config', '--dry-run'):
            self.assertNotIn(flag, cmd)

    def test_upgrade_order(self):
        names = [t.get('name', '') for t in _load('upgrade-bob.yml')]
        cleanup = next(i for i, n in enumerate(names) if 'obsolete' in n and n.startswith('Remove'))
        upgrade = next(i for i, n in enumerate(names) if n.startswith('Run bobctl upgrade'))
        model = next(i for i, n in enumerate(names) if n.startswith('Run bobctl update-model-config'))
        self.assertLess(cleanup, upgrade)
        self.assertLess(upgrade, model)

    def test_cleanup_deletes_the_two_fixed_names_when_chart_no_longer_creates_them(self):
        tasks = _load('upgrade-bob.yml')
        task = _find_task(tasks, 'Remove obsolete IBM Bob ClusterRole')
        self.assertEqual(task['when'], '_ibm_bob_remove_cluster_role | bool')
        self.assertEqual([i['name'].split('{{')[0] for i in task['loop']],
                         ['ibm-bob-role-', 'ibm-bob-rolebinding-'])
        self.assertIn('--ignore-not-found', task['vars']['_p_command'])
        flag = _find_task(tasks, 'Determine whether obsolete')['set_fact']['_ibm_bob_remove_cluster_role']
        env = _env()
        for create, expected in ((False, 'True'), (True, 'False')):
            values = {'bob': {'createClusterRoleBinding': create}}
            self.assertEqual(str(env.from_string(flag).render(_ibm_bob_cluster_scoped_values=values)).strip(), expected)
        # a chart without the setting keeps the role (safe default)
        self.assertEqual(str(env.from_string(flag).render(_ibm_bob_cluster_scoped_values={})).strip(), 'False')

    def test_cluster_scoped_values_path_matches_bundle_layout(self):
        task = _find_task(_load('upgrade-bob.yml'), 'Read values of the IBM Bob cluster-scoped chart')
        self.assertIn('/charts/ibm-bob-cluster-scoped/values.yaml', task['set_fact']['_ibm_bob_cluster_scoped_values'])

    def test_update_model_config_command(self):
        task = _find_task(_load('upgrade-bob.yml'), 'Run bobctl update-model-config')
        self.assertEqual(task['when'], "_ibm_bob_model_config_file != ''")
        env = _env()

        def render(secret_names):
            return ' '.join(str(env.from_string(task['vars']['_p_command']).render(
                _ibm_bob_bobctl_path='/b/bobctl', _ibm_bob_model_config_file='/s/mg.yaml',
                status_dir='/s',
                current_ibm_bob_cluster={'project': 'ibm-bob', 'model_gateway_secret_names': secret_names}
            )).split())

        with_secrets = render({'KEY': 'vault-secret'})
        self.assertIn('update-model-config --model-config /s/mg.yaml --update-secrets', with_secrets)
        self.assertIn('--cleanup', with_secrets)
        self.assertNotIn('--update-secrets', render({}))

    def test_all_upgrade_commands_go_through_run_command(self):
        # run-command logs the activity and skips the command in dry-run mode
        for task in _load('upgrade-bob.yml'):
            self.assertEqual(set(task) & {'shell', 'command', 'kubernetes.core.k8s'}, set(), task.get('name'))


class TestBobWaitForReady(unittest.TestCase):

    def ready(self, upgrade, resource):
        task = _find_task(_load('wait-for-ready.yml'), 'Wait for the Bob custom resource')
        env = _env()
        res = env.from_string('{{ ' + task['until'].strip() + ' }}').render(
            _ibm_bob_cr={'resources': [] if resource is None else [resource]},
            _ibm_bob_version='2.0.1', _upgrade_bob=upgrade)
        return res is True or str(res).strip() == 'True'

    @staticmethod
    def res(version, generation, degraded_observed, available='True', degraded='False'):
        """Conditions as observed on a live 2.0.0 -> 2.0.1 upgrade: Available has no
        observedGeneration, only Degraded carries the current one."""
        conditions = [{'type': 'Available', 'status': available},
                      {'type': 'Progressing', 'status': 'True', 'observedGeneration': 1}]
        if degraded is not None:
            cond = {'type': 'Degraded', 'status': degraded}
            if degraded_observed is not None:
                cond['observedGeneration'] = degraded_observed
            conditions.append(cond)
        return {'metadata': {'generation': generation}, 'spec': {'version': version},
                'status': {'conditions': conditions}}

    def test_install_wait_is_unchanged(self):
        self.assertTrue(self.ready(False, self.res('2.0.0', 3, 1)))
        self.assertTrue(self.ready(False, self.res('2.0.0', 3, 1, degraded=None)))
        self.assertFalse(self.ready(False, self.res('2.0.0', 3, 3, available='False')))
        self.assertFalse(self.ready(False, None))

    def test_upgrade_does_not_return_on_stale_state(self):
        self.assertFalse(self.ready(True, self.res('2.0.0', 3, 3)))      # still the old version
        self.assertFalse(self.ready(True, self.res('2.0.1', 4, 3)))      # Degraded from an older generation

    def test_upgrade_waits_while_degraded(self):
        self.assertFalse(self.ready(True, self.res('2.0.1', 4, 4, degraded='True')))

    def test_upgrade_waits_without_degraded_condition(self):
        self.assertFalse(self.ready(True, self.res('2.0.1', 4, 4, degraded=None)))

    def test_upgrade_ready_when_reconciled(self):
        self.assertTrue(self.ready(True, self.res('2.0.1', 4, 4)))
        self.assertTrue(self.ready(True, self.res('2.0.1', 4, None)))     # no observedGeneration reported

    def test_upgrade_ignores_available_and_progressing_generation(self):
        # live values: Available without observedGeneration, Progressing stuck at generation 1
        self.assertTrue(self.ready(True, self.res('2.0.1', 2, 2)))

    def test_upgrade_not_ready_without_available(self):
        self.assertFalse(self.ready(True, self.res('2.0.1', 4, 4, available='False')))
        self.assertFalse(self.ready(True, None))


class TestBobUninstallDryRun(unittest.TestCase):
    """uninstall-bob.yml must be safe under cpd_dry_run (state: removed with --dry-run)."""

    @staticmethod
    def _guarded(task):
        return 'cpd_dry_run' in str(task.get('when', ''))

    def test_no_unguarded_k8s_changes(self):
        for task in _load('uninstall-bob.yml'):
            k8s = task.get('kubernetes.core.k8s')
            if k8s is not None:
                self.assertTrue(self._guarded(task), 'unguarded k8s change: %s' % task.get('name'))

    def test_no_unguarded_vault_changes(self):
        for task in _load('uninstall-bob.yml'):
            role = (task.get('include_role') or {}).get('name', '')
            if role.startswith('vault-'):
                self.assertTrue(self._guarded(task), 'unguarded vault change: %s' % task.get('name'))

    def test_no_unguarded_shell_that_changes_the_cluster(self):
        # read-only shell/command checks are allowed; anything that deletes/patches is not
        for task in _load('uninstall-bob.yml'):
            for module in ('shell', 'command'):
                if module in task:
                    cmd = str(task[module])
                    if re.search(r'\boc (delete|patch|apply)\b|helm (uninstall|upgrade|install)', cmd):
                        self.assertTrue(self._guarded(task), 'unguarded command: %s' % task.get('name'))

    def test_every_run_command_has_a_description_and_environment(self):
        for task in _load('uninstall-bob.yml'):
            if (task.get('include_role') or {}).get('name') == 'run-command':
                variables = task.get('vars') or {}
                self.assertIn('_p_command_description', variables, task.get('name'))
                self.assertIn('_p_command_environment', variables, task.get('name'))

    def test_removals_are_logged_in_order(self):
        commands = []
        for task in _load('uninstall-bob.yml'):
            if (task.get('include_role') or {}).get('name') == 'run-command':
                commands.append(re.sub(r'\s+', ' ', str(task['vars']['_p_command'])))
        expected = ['oc delete bob bob-cr', 'oc delete bobidp bob-idp', 'oc patch bobidp bob-idp',
                    'helm uninstall ibm-bob', 'oc delete namespace {{ current_ibm_bob_cluster.project }}',
                    'oc delete namespace {{ current_ibm_bob_cluster.operators_project',
                    'oc delete inferenceservice', 'oc delete servingruntime', 'oc delete job', 'oc delete pvc',
                    'oc delete namespace {{ _ibm_bob_models_project }}',
                    'oc delete certificate', 'oc delete issuer', 'oc delete -f']
        position = -1
        for fragment in expected:
            idx = next((i for i, c in enumerate(commands) if fragment in c), None)
            self.assertIsNotNone(idx, 'missing removal command: %s' % fragment)
            self.assertGreater(idx, position, 'out of order: %s' % fragment)
            position = idx


ROLES_DIR = os.path.join(TASKS_DIR, '../..')
DRY_RUN_FILES = [
    ('ibm-bob-cluster', f) for f in (
        'main.yml', 'install-bob.yml', 'upgrade-bob.yml', 'airgap-apply.yml',
        'setup-cluster-ingress-cert.yml', 'wait-for-ready.yml', 'validate-prereqs.yml',
        'validate-openshift-ai-prereqs.yml', 'check-bob-upgrade.yml')
] + [
    ('ibm-bob-openshift-ai-models', f) for f in (
        'main.yml', 'download-or-verify-models.yml', 'deploy-inference-services.yml',
        'wait-for-inference-services.yml', 'apply-object.yml')
]
# Included only when cpd_dry_run is not set (checked by test_upload_is_not_included_in_dry_run)
NOT_IN_DRY_RUN = [('ibm-bob-openshift-ai-models', 'upload-model-weights.yml'),
                  ('ibm-bob-openshift-ai-models', 'copy-model-to-pvc.yml')]
SECRET_VARIABLES = re.compile(r'_ibm_bob_(entitlement_key|hf_token|[a-z_]*creds|model_gateway_secrets)\b|secret_value')
CHANGING_COMMAND = re.compile(r'\boc (apply|delete|patch|create|cp|exec|label|annotate)\b|helm (install|upgrade|uninstall)|bobctl')


def _load_role_file(role, name):
    with open(os.path.join(ROLES_DIR, role, 'tasks', name)) as f:
        return yaml.safe_load(f)


def _flatten(tasks, guarded=False):
    """Yield (task, guarded_by_dry_run) for every task, descending into blocks."""
    for task in tasks:
        here = guarded or 'cpd_dry_run' in str(task.get('when', ''))
        if 'block' in task:
            for sub in _flatten(task['block'], here):
                yield sub
            for key in ('rescue', 'always'):
                for sub in _flatten(task.get(key, []), here):
                    yield sub
        else:
            yield task, here


class TestBobDryRunInstallPath(unittest.TestCase):
    """The apply path must not change the cluster in dry run, and must not log secrets."""

    def test_no_unguarded_cluster_changes(self):
        for role, name in DRY_RUN_FILES:
            for task, guarded in _flatten(_load_role_file(role, name)):
                changing = False
                k8s = task.get('kubernetes.core.k8s')
                if k8s is not None or 'kubernetes.core.k8s_exec' in task:
                    changing = True
                for module in ('shell', 'command'):
                    if module in task and CHANGING_COMMAND.search(str(task[module])):
                        changing = True
                if changing:
                    self.assertTrue(guarded, 'unguarded change in %s/%s: %s' % (role, name, task.get('name')))

    def test_end_role_is_no_longer_used_for_dry_run(self):
        for task in _load('main.yml'):
            if 'block' in task and 'cpd_dry_run' in str(task.get('when', '')):
                self.assertFalse(any('meta' in t for t in task['block']), task.get('name'))

    def test_upload_is_not_included_in_dry_run(self):
        tasks = list(_flatten(_load_role_file('ibm-bob-openshift-ai-models', 'download-or-verify-models.yml')))
        includes = [(t, g) for t, g in tasks if str(t.get('include_tasks', '')) in
                    ('upload-model-weights.yml', 'copy-model-to-pvc.yml')]
        self.assertTrue(includes)
        for task, guarded in includes:
            self.assertTrue(guarded, task.get('name'))

    def test_logged_commands_and_comments_do_not_reference_secrets(self):
        for role, name in DRY_RUN_FILES:
            for task, _ in _flatten(_load_role_file(role, name)):
                variables = task.get('vars') or {}
                for key in ('_p_command', '_p_command_description', '_p_activity_description',
                            '_p_activity_comment', '_obj_description', '_obj_file_name'):
                    self.assertIsNone(SECRET_VARIABLES.search(str(variables.get(key, ''))),
                                      'secret in %s of %s/%s: %s' % (key, role, name, task.get('name')))

    def test_applied_objects_are_never_secrets(self):
        # apply-object.yml writes the object to a YAML file that is logged
        for role, name in DRY_RUN_FILES:
            for task, _ in _flatten(_load_role_file(role, name)):
                if task.get('include_tasks') == 'apply-object.yml':
                    definition = str((task.get('vars') or {}).get('_obj_definition', ''))
                    self.assertNotIn('kind: Secret', definition.replace("'", '').replace('"', ''))
                    self.assertIsNone(SECRET_VARIABLES.search(definition), task.get('name'))

    def test_waits_are_logged_as_comments_in_dry_run(self):
        for role, name, fragment in (
                ('ibm-bob-cluster', 'wait-for-ready.yml', 'Log the wait for IBM Bob'),
                ('ibm-bob-cluster', 'setup-cluster-ingress-cert.yml', 'Log the certificate and issuer'),
                ('ibm-bob-openshift-ai-models', 'wait-for-inference-services.yml', 'Log wait for the InferenceServices')):
            tasks = [t for t, _ in _flatten(_load_role_file(role, name))]
            self.assertTrue(any(t.get('name', '').startswith(fragment) for t in tasks), (role, name))





class TestConfigTemplateExternalDomain(unittest.TestCase):
    """bobctl update-model-config renders with helm template, which cannot detect the domain."""

    TEMPLATE = os.path.join(TASKS_DIR, '../templates/config.yaml.j2')

    def render(self, **extra):
        from jinja2 import Environment
        ctx = dict(_ibm_bob_version='2.0.1', current_ibm_bob_cluster={'project': 'ibm-bob', 'premium_packages': {}},
                   ocp_storage_class_file='f', ocp_storage_class_block='b', _ibm_bob_image_pull_prefix='icr.io')
        ctx.update(extra)
        env = Environment(trim_blocks=True)
        return yaml.safe_load(env.from_string(open(self.TEMPLATE).read()).render(**ctx))

    def test_external_domain_is_set(self):
        cfg = self.render(_ibm_bob_external_domain='apps.example.com')
        self.assertEqual(cfg['bob']['externalDomain'], 'apps.example.com')

    def test_external_domain_is_left_out_when_unknown(self):
        self.assertNotIn('externalDomain', self.render(_ibm_bob_external_domain='')['bob'])
        self.assertNotIn('externalDomain', self.render()['bob'])

    def test_domain_is_read_before_the_config_is_rendered(self):
        main = open(os.path.join(TASKS_DIR, 'main.yml')).read()
        self.assertLess(main.index('Set the cluster base domain'), main.index('Render config.yaml for IBM Bob'))


class TestSmokeTestsDryRun(unittest.TestCase):
    """The smoke tests wait for things that a dry run never creates or removes."""

    def test_every_top_level_smoke_test_block_is_skipped_in_dry_run(self):
        path = os.path.join(TASKS_DIR, '../../../../80-smoke-tests/ibm-bob-cluster-smoke-tests/tasks/main.yml')
        for task in yaml.safe_load(open(path)):
            if 'block' in task:
                self.assertIn('cpd_dry_run', str(task.get('when', '')), task.get('name'))


if __name__ == '__main__':
    unittest.main()
