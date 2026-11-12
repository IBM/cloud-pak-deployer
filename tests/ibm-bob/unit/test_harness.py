"""
Tests for the integration test harness: the modes of run_integration_tests.sh and the
phases of test-assert-live.yml. These are static checks; the harness itself needs a cluster.
"""

import os, re, unittest, yaml

IT_DIR = os.path.join(os.path.dirname(__file__), '..')
SCRIPT = open(os.path.join(IT_DIR, 'run_integration_tests.sh')).read()
PLAYBOOKS = os.path.join(IT_DIR, 'playbooks')
ASSERT = yaml.safe_load(open(os.path.join(PLAYBOOKS, 'test-assert-live.yml')))[0]['tasks']


def _full_sequence():
    return re.search(r'^FULL_SEQUENCE="([^"]+)"', SCRIPT, re.M).group(1).split()


def _valid_modes():
    line = next(l for l in SCRIPT.splitlines() if l.strip().endswith('MODES+=("${m}") ;;'))
    return set(line.strip().split(')')[0].split('|'))


def _allowed_phases():
    task = next(t for t in ASSERT if t.get('name') == 'Check the assertion phase')
    return set(re.findall(r"'([a-z-]+)'", task['assert']['that']))


def _phase_conditions():
    out = set()

    def walk(tasks):
        for t in tasks:
            out.update(re.findall(r"'([a-z-]+)'", str(t.get('when', ''))))
            walk(t.get('block', []))
    walk(ASSERT)
    return out


class TestHarnessModes(unittest.TestCase):
    def test_full_sequence(self):
        self.assertEqual(_full_sequence(), [
            'dry-run', 'install', 'dry-run-upgrade', 'upgrade', 'dry-run-remove', 'remove',
            'airgap-full', 'remove', 'airgap-semi', 'remove', 'cleanup'])

    def test_every_sequence_step_is_a_valid_mode(self):
        self.assertTrue(set(_full_sequence()) <= _valid_modes())

    def test_dry_run_upgrade_runs_between_install_and_upgrade(self):
        seq = _full_sequence()
        self.assertIn('dry-run-upgrade', _valid_modes())
        self.assertEqual(seq.index('dry-run-upgrade'), seq.index('install') + 1)
        self.assertEqual(seq.index('upgrade'), seq.index('dry-run-upgrade') + 1)

    def test_every_valid_mode_is_dispatched(self):
        for mode in _valid_modes():
            self.assertRegex(SCRIPT, re.compile(r'^\s+%s\)' % re.escape(mode), re.M), mode)

    def test_dry_run_modes_do_not_need_an_entitlement_key(self):
        line = next(l for l in SCRIPT.splitlines() if 'needs_entitlement=true' in l and 'case' in l)
        for mode in ('dry-run', 'dry-run-upgrade', 'dry-run-remove'):
            self.assertIn(mode, line.split(')')[0])
        self.assertNotIn('upgrade|', line.replace('dry-run-upgrade', ''))

    def test_upgrade_needs_an_entitlement_key(self):
        line = next(l for l in SCRIPT.splitlines() if 'needs_entitlement=true' in l and 'case' in l)
        self.assertNotRegex(line.split(')')[0].replace('dry-run-upgrade', ''), r'\bupgrade\b')

    def test_dry_run_phases_use_snapshot_and_assert(self):
        body = re.search(r'dry_run_phase\(\) \{(.*?)\n\}', SCRIPT, re.S).group(1)
        self.assertLess(body.index('assert_phase snapshot'), body.index('deployer apply --dry-run'))
        self.assertLess(body.index('deployer apply --dry-run'), body.index('assert_phase "${phase}"'))

    def test_phases_use_the_right_configs(self):
        for fn, cfg in (('phase_dry_run', 'it-bob-install.yaml dry-run'),
                        ('phase_dry_run_upgrade', 'it-bob-upgrade.yaml dry-run-upgrade'),
                        ('phase_dry_run_remove', 'it-bob-remove.yaml dry-run-remove')):
            self.assertRegex(SCRIPT, r'%s\(\) \{ dry_run_phase %s; \}' % (fn, re.escape(cfg)))
        body = re.search(r'phase_upgrade\(\) \{(.*?)\n\}', SCRIPT, re.S).group(1)
        self.assertIn('use_bob_config it-bob-upgrade.yaml', body)
        self.assertIn('assert_phase upgrade', body)


class TestAssertPlaybook(unittest.TestCase):
    PHASES = {'install', 'upgrade', 'airgap', 'remove', 'snapshot', 'dry-run', 'dry-run-upgrade', 'dry-run-remove'}

    def test_allowed_phases(self):
        self.assertEqual(_allowed_phases(), self.PHASES)

    def test_phases_used_by_the_script_are_allowed(self):
        used = set(re.findall(r'assert_phase ([a-z-]+)', SCRIPT)) | set(re.findall(r'dry_run_phase \S+ ([a-z-]+)', SCRIPT))
        self.assertTrue(used <= self.PHASES, used - self.PHASES)

    def test_every_phase_has_assertions(self):
        used = _phase_conditions()
        self.assertTrue(self.PHASES <= used, self.PHASES - used)

    def test_included_task_files_exist(self):
        for name in ('bob-state.yml', 'assert-activity-log.yml'):
            self.assertTrue(os.path.exists(os.path.join(PLAYBOOKS, name)), name)
            yaml.safe_load(open(os.path.join(PLAYBOOKS, name)))

    def test_state_does_not_read_secret_values(self):
        # only the presence of the Keycloak key in the vault file is recorded
        state = open(os.path.join(PLAYBOOKS, 'bob-state.yml')).read()
        self.assertNotIn('vault-get-secret', state)
        self.assertNotIn('b64decode', state)

    def test_snapshot_has_no_changing_status_fields(self):
        state = open(os.path.join(PLAYBOOKS, 'bob-state.yml')).read()
        self.assertNotRegex(state, r'(?m)^[^#\n]*resourceVersion')

    def test_foreign_images_filter_permits_private_registry_and_cpopen(self):
        from jinja2.nativetypes import NativeEnvironment
        env = NativeEnvironment()
        env.filters['regex_escape'] = re.escape
        env.tests['match'] = lambda val, pat: bool(re.search(pat, val))

        def find_task(tasks, name):
            for t in tasks:
                if t.get('name') == name:
                    return t
                sub = find_task(t.get('block', []), name)
                if sub:
                    return sub
            return None

        task = find_task(ASSERT, 'Find the images that do not come from the private registry')
        expr = task['set_fact']['_it_foreign_images']
        images = [
            {'namespace': 'ibm-bob', 'pod': 'p1', 'container': 'c1', 'image': 'de.icr.io/bob-on-prem/ibm-bob-gateway:2.0.1'},
            {'namespace': 'ibm-bob', 'pod': 'p2', 'container': 'ibm-usage-metering-instance', 'image': 'icr.io/cpopen/cpfs/ibm-usage-metering-instance@sha256:f398b25e5a2d02bc75fcdbf1cd848448c0ffe07ee4eb38630ca87971c007d7f7'},
            {'namespace': 'ibm-bob-operators', 'pod': 'p3', 'container': 'ibm-usage-metering-operator', 'image': 'icr.io/cpopen/ibm-usage-metering-operator@sha256:6da2b2e3fa74881bccfb4d0baded7c7a813595454c01cdcee5ad2f26de7f35ff'},
            # Dummy fixture: an un-mirrored foreign image must still be flagged
            {'namespace': 'ibm-bob', 'pod': 'p4', 'container': 'c4', 'image': 'docker.io/library/nginx:latest'},
        ]
        res = env.from_string(expr).render(_it_images=images, _it_registry_prefix='de.icr.io/bob-on-prem')
        self.assertEqual(res, [images[3]])


if __name__ == '__main__':
    unittest.main()
