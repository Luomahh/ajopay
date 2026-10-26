# Local SQL regression tests

From this directory, using Node 24 and npm:

```sh
npm ci --ignore-scripts
npm test
```

The pinned PGlite dependency runs PostgreSQL in memory. The runner creates the
minimal platform fixture, applies `../bootstrap/000_profiles.sql`, then every
migration in filename order, and executes every SQL test. It verifies that each
suite restores table contents and the session role. It accepts no database URL,
reads no `.env`, and never connects to Supabase. Dependency installation needs
network access; test execution does not.

`platform.sql` models only the auth users, JWT-subject helper, database roles,
default grants and Storage metadata needed by this repository. **Never deploy
this fixture.** It does not reproduce Supabase Auth, PostgREST, Storage uploads,
Realtime, jobs, or hosting configuration. Tests exercise SQL constraints, RPCs
and row-level authorization, not actual authentication or HTTP integration.
PGlite uses one connection; this does not prove concurrent request safety,
load capacity or production recovery. Sequence counters need not roll back. Table-content and role checks do not prove
complete rollback of schema/grant changes or transaction state.

The fresh profile baseline is a conservative reconstruction, not a hosted schema
export. Keep it outside migrations so automated deployment cannot silently replay
it on the existing project. Exact hosted parity and migration-history reconciliation
remain outstanding. Before deployment, run integration and concurrent-request
tests against a disposable full Supabase stack and review a sanitized schema diff.
Do not reset, bootstrap or replay migrations on the live project.

## Real local Supabase integration

Use Supabase CLI **2.122.0**, Node 24 and a supported native runtime (Apple Silicon
macOS 14+, or supported Linux). Docker is an alternative. The CLI is experimental
in this mode, so its version is checked before startup.

```sh
npm ci --ignore-scripts
node --test http-smoke.test.mjs
npm run test:integration
```

If the CLI is outside PATH, set `AJOPAY_SUPABASE_CLI` to its executable path.
Set `AJOPAY_TEST_RUNTIME=docker` to use a running Docker engine instead of native.
First startup downloads service archives and may take several minutes. The CLI
may also need access to its standard `~/.supabase` runtime directory.

The runner makes a fresh temporary project and runtime home, without inheriting
Supabase credentials or reading the app's `.env`. It starts PostgreSQL, Auth,
PostgREST and Storage; applies the real baseline/migrations (never `platform.sql`);
runs SQL suites; and uses real Auth-issued JWTs to check profile privacy and
protected-field/anonymous/invalid-token denial. Users are admin-created and then
password-authenticated. This does **not** test the public signup/email-confirmation
flow, group RPCs over HTTP, Storage file uploads, or concurrent requests.

Cleanup destroys only the stack belonging to that generated temporary project.
If cleanup fails, it prints the retained workspace path for a targeted retry.
CLI output is withheld because local credentials can appear in it; no logs are
uploaded as CI artifacts. The manual `Disposable Supabase integration` workflow
runs the same checks without repository secrets or deployment actions.

Status: the runner is prepared; native startup encountered a runtime/connection
failure during local verification. Do not treat this as a passing full-stack run
until the command completes successfully. Local fixture SQL results remain a
separate evidence set. Hosted schema/history comparison is still outstanding.
