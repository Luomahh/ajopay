# Secret checks and client configuration

## Implemented guardrails

Run from the repository root before sharing a diff, committing or building:

```sh
python3 -m unittest discover -s scripts -p 'test_security_check.py'
python3 scripts/security_check.py
```

The dependency-free Python scanner reads tracked and nonignored untracked UTF-8 text. It additionally reads the ignored root `.env` and explicitly declared `.env`-named Flutter asset files, because ignoring a file in Git does not stop Flutter packaging it. It reports only JSON-escaped paths, line numbers and rule names; it never prints matched values. Exit code 1 means findings; 2 means scanning could not complete. Binary files are not generally scanned; binary client configuration fails validation. Symlinks require review rather than following them outside the repository.

Detections include private-key headers, common Paystack/Flutterwave/Supabase secret-key formats, GitHub tokens and JWTs whose decoded role is `service_role`. Decoding a JWT identifies a dangerous role; it is not signature verification. Client `.env` permits only `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_PUBLISHABLE_KEY`; values must match the permitted public URL/key form. Any new public configuration requires an explicit reviewed allowlist change. Public Supabase keys still require correctly enforced RLS and server authorization.

Do not put payment-provider keys, service-role credentials, private keys, BVN/NIN values or access tokens into Flutter assets, source code, tests, logs, screenshots or documentation. Build synthetic scanner fixtures from fragments so the tests exercise detections without storing credential-shaped literals. Never add a broad allowlist to silence a failure.

## CI history coverage

`.github/workflows/security.yml` runs the Python tests/scanner and installs Gitleaks **v8.30.0** from its Go module. Checkout fetches history and Gitleaks scans all fetched refs with full finding redaction. This avoids the separate Gitleaks Action licensing dependency. The first hosted run remains to be verified after pushing. CI cannot see a developer's ignored `.env`; run the local check before every build. CI should become a required protected-branch check once repository settings are configured. Workflow files alone do not enforce branch protection.

Gitleaks is complementary, not a guarantee that every secret is detectable. The history scan may reveal pre-existing findings. Do not automatically ignore them: investigate without copying values into tickets or chat, rotate/revoke confirmed leaked credentials, then coordinate any necessary history cleanup with the repository owner. Removing a secret from the current file does not remove it from history.

The scanner does not audit deployment secret stores, generated build outputs, arbitrary ignored files, personal credentials outside the repository, dependency vulnerabilities, identity-data leakage, or authorization correctness. It is not a replacement for manual security review, RLS tests or a release audit.

Sources checked for this implementation:
- [Gitleaks official commands and redaction](https://github.com/gitleaks/gitleaks/blob/master/README.md)
- [Pinned release module and Go requirement](https://github.com/gitleaks/gitleaks/blob/v8.30.0/go.mod)

## Security reviewer role

Review diffs and these check results. Report file, line, category and remediation, never the value. Verify client/server boundaries and redacted error handling. Do not open unrelated credential files, rotate keys, alter access policies or rewrite Git history without the relevant authorized task. A reviewer agent complements deterministic enforcement; its approval alone is not a release gate.
