# Supabase backend

This directory versions the AjoPay backend alongside the Flutter client.

## Migrations, in order

| File | Purpose |
| --- | --- |
| `migrations/202609240001_draft_groups.sql` | Draft groups, owner membership, read policies, creation audit, retry-safe creation |
| `migrations/202610070001_savings_modes.sql` | Rotating/target modes, contribution frequencies, invite codes, controlled joining |
| `migrations/202610080001_group_activation.sql` | Member-scoped details, one-time payout order, explicit agreement, atomic activation/schedules |
| `migrations/202610090001_contributions.sql` | Payment windows, member reports, leader review, duplicate protection, private audit history |

These migrations have already been applied to the current hosted project. Do not rerun them there. They are intentionally not silent on conflicting existing objects.

## Fresh-project prerequisites

The migrations extend an existing Supabase project. Before applying them to a fresh project, recreate the pre-existing `public.profiles` schema and signup trigger. The inspected baseline includes `id` (the auth user ID), `full_name`, `phone`, `trust_score`, and `created_at`, with own-profile read/insert/update policies and the `handle_new_user()` signup trigger. Its original DDL is not included in these feature migrations. See [group setup](../docs/GROUPS_SETUP.md) for the inspected baseline and deployment notes.

Use only the project URL and public publishable/anon client key in the Flutter `.env`; copy the placeholders from `.env.example`. Never put a database password, service-role key, or personal access token in client assets or this repository. Supabase Auth settings such as redirect URLs must be configured in the dashboard for your deployment.

## Tests

Run each SQL test as postgres in the Supabase SQL Editor against a suitably configured test project. They create synthetic users inside a transaction and end with `rollback`; do not replace it with `commit`.

- `tests/draft_groups.sql`: base creation and authorization checks.
- `tests/group_activation.sql`: joining, capacity, privacy, agreement, activation, and schedules.
- `tests/contributions.sql`: payment windows, retries, correction/review, private reads, and audit history.

The group activation suite passed live on 2026-10-08, and contribution suite on 2026-10-09. The older base draft suite is retained but was not separately executed in those milestones.

Live user data, auth credentials, storage objects, and database backups are not committed. Hosting the source on GitHub does not migrate or redeploy the running Supabase project.
