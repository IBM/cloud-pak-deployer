"""
Tests for ibm-bob-variables version resolution logic and version definition files.
"""

import sys, os, unittest, glob, yaml

VERSIONS_DIR = os.path.join(
    os.path.dirname(__file__),
    '../../automation-roles/50-install-cloud-pak/ibm_bob/ibm-bob-variables/vars/versions'
)

class TestIbmBobVersions(unittest.TestCase):

    def test_version_files_exist(self):
        files = glob.glob(os.path.join(VERSIONS_DIR, '*.yml'))
        self.assertGreater(len(files), 0, "No version definition files found")

    def test_200_version_file_content(self):
        v200_file = os.path.join(VERSIONS_DIR, '2.0.0.yml')
        self.assertTrue(os.path.exists(v200_file), "2.0.0.yml does not exist")
        with open(v200_file, 'r') as f:
            data = yaml.safe_load(f)

        self.assertEqual(data.get('_ibm_bob_release_tag'), 'v2.0.0')
        self.assertEqual(data.get('_ibm_bob_bundle_filename'), 'ibm-bob-install-20260924-163534.tgz')
        self.assertTrue(data.get('_ibm_bob_bundle_url', '').startswith('https://github.com/IBM/ibm-bob/releases/download/v2.0.0/'))
        self.assertEqual(data.get('_ibm_bob_bundle_sha256'), '3b6dc70cd0a236d2e58bb23d19804e3e73e3de9b7b3d77850b35f463f30c3726')
        self.assertEqual(data.get('_ibm_bob_supported_ocp_versions'), ['4.20', '4.21', '4.22'])
        self.assertIn('bob_ide', data.get('_ibm_bob_companion_versions', {}))
        self.assertIn('bob_shell', data.get('_ibm_bob_companion_versions', {}))
        self.assertIn('premium_package_z', data.get('_ibm_bob_companion_versions', {}))
        self.assertEqual(data.get('_ibm_bob_premium_package_keys', {}).get('rag'), 'bob.rag.enabled')
        self.assertEqual(data.get('_ibm_bob_premium_package_keys', {}).get('z_proxy'), 'bob.zProxy.enabled')
        self.assertEqual(data.get('_ibm_bob_premium_package_keys', {}).get('understand'), 'bob.understand.enabled')

    def test_version_resolution_logic(self):
        files = glob.glob(os.path.join(VERSIONS_DIR, '*.yml'))
        available_versions = sorted([os.path.basename(f).replace('.yml', '') for f in files])
        
        # 'latest' should resolve to highest version
        latest_version = available_versions[-1]
        self.assertEqual(latest_version, '2.0.0')

        # specific version should match
        self.assertIn('2.0.0', available_versions)

if __name__ == '__main__':
    unittest.main()
