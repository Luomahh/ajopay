#!/usr/bin/env python3
"""Redacted working-tree guardrail; not a complete secret audit."""
import argparse
import base64
import json
from pathlib import Path
import re
import subprocess

RULES = {
    'private-key': re.compile(r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'),
    'provider-secret': re.compile(r'\b(?:sk_(?:live|test)_[A-Za-z0-9]{16,}|sb_secret_[A-Za-z0-9_-]{16,}|FLWSECK_[A-Za-z0-9_-]{16,})'),
    'github-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
}
JWT = re.compile(r'\beyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+')
PUBLIC_KEYS = {'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEY'}


def jwt_role(value):
    try:
        payload = value.split('.')[1]
        return json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4))).get('role')
    except (ValueError, IndexError, TypeError, AttributeError):
        return None


def inspect_text(text, client_env=False):
    findings = set()
    for number, line in enumerate(text.splitlines(), 1):
        for name, pattern in RULES.items():
            if pattern.search(line):
                findings.add((number, name))
        for match in JWT.finditer(line):
            if jwt_role(match.group()) == 'service_role':
                findings.add((number, 'supabase-service-role'))
        if not client_env:
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if '=' not in stripped:
            findings.add((number, 'invalid-client-config'))
            continue
        key, value = stripped.split('=', 1)
        key = key.strip()
        value = value.strip().strip('\"\'')
        if key not in PUBLIC_KEYS:
            findings.add((number, 'nonpublic-client-config'))
        elif key == 'SUPABASE_URL':
            if not re.fullmatch(r'https://[a-z0-9-]+\.supabase\.co/?|http://(?:localhost|127\.0\.0\.1):[0-9]+/?', value):
                findings.add((number, 'invalid-public-url'))
        elif not (value.startswith('sb_publishable_') or jwt_role(value) == 'anon'):
            findings.add((number, 'nonpublic-client-key'))
    return sorted(findings)


def scan(root):
    listed = subprocess.run(['git', '-C', str(root), 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], capture_output=True, check=True).stdout
    paths = {Path(p.decode()) for p in listed.split(b'\0') if p}
    envs = {Path('.env')}
    spec = root / 'pubspec.yaml'
    if spec.exists():
        for match in re.finditer(r'^\s*-\s*[\"\']?([^\s\"\']+)', spec.read_text(), re.M):
            candidate = Path(match.group(1))
            if '.env' in candidate.name and not candidate.is_absolute() and '..' not in candidate.parts:
                envs.add(candidate)
    paths |= envs
    findings = []
    for relative in sorted(paths):
        path = root / relative
        if path.is_symlink():
            findings.append((str(relative), 1, 'symlink-review-required'))
            continue
        if not path.is_file():
            continue
        try:
            raw = path.read_bytes()
            if b'\0' in raw:
                if relative in envs:
                    findings.append((str(relative), 1, 'invalid-client-config'))
                continue
            text = raw.decode('utf-8')
        except UnicodeDecodeError:
            if relative in envs:
                findings.append((str(relative), 1, 'invalid-client-config'))
            continue
        findings.extend((str(relative), line, rule) for line, rule in inspect_text(text, relative in envs))
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        findings = scan(args.root.resolve())
    except (OSError, subprocess.CalledProcessError):
        print('Security scan could not complete; no file contents were printed.')
        return 2
    for path, line, rule in findings:
        print(f'{json.dumps(path)}:{line}: {rule}')
    print(f'Security scan: {len(findings)} finding(s). Values are never printed.')
    return 1 if findings else 0


if __name__ == '__main__':
    raise SystemExit(main())
