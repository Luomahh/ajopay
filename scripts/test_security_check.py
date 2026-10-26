import base64
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from security_check import inspect_text, scan


def token(role):
    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    return encode({'alg': 'HS256'}) + '.' + encode({'role': role}) + '.signature'


class SecurityChecks(unittest.TestCase):
    def test_privileged_jwt(self):
        self.assertIn((1, 'supabase-service-role'), inspect_text(token('service_role')))
        self.assertEqual([], inspect_text(token('anon')))

    def test_provider_and_github_tokens(self):
        for prefix in ['sk_' + 'test_', 'sk_' + 'live_', 'sb_' + 'secret_', 'FLW' + 'SECK_', 'gh' + 'p_', 'github_' + 'pat_']:
            self.assertTrue(inspect_text(prefix + 'X' * 40))

    def test_private_key(self):
        self.assertTrue(inspect_text('-----BEGIN ' + 'PRIVATE KEY-----'))

    def test_client_config(self):
        self.assertEqual([], inspect_text('SUPABASE_URL=https://example.supabase.co\nSUPABASE_ANON_KEY=' + token('anon'), True))
        self.assertEqual([], inspect_text('SUPABASE_PUBLISHABLE_KEY=sb_publishable_example', True))
        self.assertTrue(inspect_text('SUPABASE_ANON_KEY=' + token('service_role'), True))
        self.assertTrue(inspect_text('UNEXPECTED=anything', True))
        self.assertTrue(inspect_text('SUPABASE_URL=https://user:password@example.com', True))
        self.assertTrue(inspect_text('continuation', True))

    def test_ignored_flutter_env_and_untracked_and_tracked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            (root / '.gitignore').write_text('.env\nconfig/.env.mobile\n')
            (root / 'pubspec.yaml').write_text('flutter:\n  assets:\n    - config/.env.mobile\n')
            (root / 'config').mkdir()
            secret = 'sk_' + 'test_' + 'X' * 40
            (root / '.env').write_text('PAYMENT_KEY=' + secret)
            (root / 'config/.env.mobile').write_text('SUPABASE_ANON_KEY=' + token('service_role'))
            (root / 'untracked.txt').write_text(secret)
            (root / 'tracked.txt').write_text(secret)
            subprocess.run(['git', '-C', directory, 'add', 'tracked.txt'], check=True)
            found = scan(root)
            self.assertNotIn(secret, repr(found))
            self.assertEqual({'.env', 'config/.env.mobile', 'tracked.txt', 'untracked.txt'}, {item[0] for item in found})
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('security_check.py')), '--root', directory], capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertNotIn(secret, result.stdout + result.stderr)
            self.assertIn('provider-secret', result.stdout)

    def test_binary_env_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            (root / '.env').write_bytes(b'\0secret')
            self.assertIn(('.env', 1, 'invalid-client-config'), scan(root))


if __name__ == '__main__':
    unittest.main()
