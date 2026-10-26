# Supabase backend

This directory versions the AjoPay backend alongside the Flutter client.

## Migrations, in order

| File | Purpose |
| --- | --- |
| `migrations/202609240001_draft_groups.sql` | Draft groups, owner membership, read policies, creation audit, retry-safe creation |
| `migrations/202610070001_savings_modes.sql` | Rotating/target modes, contribution frequencies, invite codes, controlled joining |
| `migrations/202610080001_group_activation.sql` | Member-scoped details, one-time payout order, explicit agreement, atomic activation/schedules |
| `migrations/202610090001_contributions.sql` | Payment windows, member reports, leader review, duplicate protection, private audit history |
| `migrations/202610100001_receipts_and_chat.sql` | Private immutable receipt storage, submission notes/evidence snapshots, member-only text chat |
| `migrations/202610100002_payouts.sql` | Funded scheduled payouts, recipient acknowledgement, disputes, private history, and round completion |

These migrations have already been applied to the current hosted project. Do not rerun them there. They are intentionally not silent on conflicting existing objects.

## Fresh-project prerequisites

The original hosted `public.profiles` DDL was not checked in. For an **empty fresh project only**, `bootstrap/000_profiles.sql` now supplies a conservative profile table, owner-only policies, protected server fields and signup trigger. Apply it before the feature migrations as the database owner. It deliberately fails on conflicting objects. It is not an export of hosted DDL, and must not be applied to the existing project. Hosted parity and migration history still need reconciliation.

The separate [local regression harness](testing/README.md) rebuilds these application objects against an in-memory PostgreSQL platform fixture. Its fixture must never be deployed to Supabase.

Use only the project URL and public publishable/anon client key in the Flutter `.env`; copy the placeholders from `.env.example`. Never put a database password, service-role key, or personal access token in client assets or this repository. Supabase Auth settings such as redirect URLs must be configured in the dashboard for your deployment.

## Tests

Prefer the [local regression harness](testing/README.md) for repeatable checks. For full-stack verification, run each SQL test as postgres against a disposable, suitably configured Supabase test project. They create synthetic users inside a transaction and end with `rollback`; do not replace it with `commit`.

- `tests/payouts.sql`: rotating and target payouts, funding/date/order restrictions, privacy, retries, disputes, and full-round completion; passed live on 2026-10-10.
- `tests/draft_groups.sql`: base creation and authorization checks.
- `tests/group_activation.sql`: joining, capacity, privacy, agreement, activation, and schedules.
- `tests/receipts_and_chat.sql`: private Storage metadata access, immutable evidence, notes, history, chat authorization/retries/pagination; passed live on 2026-10-10.
- `tests/contributions.sql`: payment windows, retries, correction/review, private reads, and audit history.

The group activation suite passed live on 2026-10-08, and contribution suite on 2026-10-09. The older base draft suite is retained but was not separately executed in those milestones.

Live user data, auth credentials, storage objects, and database backups are not committed. Migration files were applied manually through the SQL Editor. GitHub deployment integration is enabled; reconcile migration history before enabling or relying on automated migration deployment. Merely storing source on GitHub does not back up live data.

The 202610110001 and 202610110002 migrations add private profiles, group bank details, versioned savings rules and separate fee assessment. Run `tests/flexible_schedules.sql` plus all earlier regression suites. These features do not implement NIN verification or collect money. See `docs/FLEXIBLE_SAVINGS.md`.

2026-10-11 verification: both new migrations are applied live, and all six rollback-only SQL suites passed against that Supabase project. Migration history still needs reconciliation before automated GitHub deployment; do not rerun these CREATE statements on the live schema.
