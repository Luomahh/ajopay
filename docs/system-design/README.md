# AjoPay system design

Engineering baseline reviewed against repository source on 2026-10-22. This is a design and source review, not evidence of a new deployment, load test or live payment. Historical test results in other documents retain their original dates.

AjoPay currently coordinates externally paid Nigerian savings groups. Leaders review member reports; recipients acknowledge externally made payouts. Neither action independently proves bank settlement. The next architecture adds provider-backed payments only after its controls and business arrangement are approved.

## Five-step framework
1. [Requirements and capacity](01-requirements.md): users, scope, product rules and measurable proposed targets.
2. [Data and API](02-data-api.md): current entities, relationships, RPC contracts and proposed payment records.
3. [Architecture](03-architecture.md): implemented components, boundaries and future payment flow.
4. [Scale, failures and security](04-reliability-security.md): failure cases, observability, recovery and release gates.
5. [Trade-offs and delivery](05-decisions-roadmap.md): decisions, alternatives and prioritized work.

**Status vocabulary:** Implemented means present in inspected source, not necessarily verified in a deployed environment. Proposed means a desired change not yet delivered. Unverified means operational evidence is missing. Externally blocked means account approval, credentials or third-party agreement is required.

| Capability | Status |
|---|---|
| Flutter/Riverpod/GoRouter; Supabase auth and SQL authorization | Implemented |
| Group creation/join/consent/activation, contribution and payout records | Implemented |
| Private receipts, chat, statements and in-app notifications | Implemented |
| External email/SMS delivery worker | Proposed; queue/preferences exist |
| Payment adapter | Implemented isolated test-only adapter; 21 offline tests documented; no public endpoint or Flutter integration |
| Bank verification, ledger, custody, identity verification, automatic payouts | Proposed / provider arrangement externally blocked |
| Database baseline | Fresh-only profiles/auth prerequisite and local SQL fixture harness versioned; hosted parity and full-stack rebuild remain unverified |
| Load capacity, recovery and availability guarantees | Unverified |

Source of truth: `supabase/migrations`, `lib/domain`, `lib/data`, feature code, and `supabase/functions/PAYMENTS_SANDBOX.md`. Read newer migrations after older definitions: several RPCs are replaced. Earlier delivery notes are historical, not contradictory current contracts.

Agent instructions are in `AGENTS.md` and `docs/AGENT_WORKFLOW.md`. Agensi is the preferred discovery source for optional skills; a marketplace does not provide AjoPay's architecture or establish that a skill is safe. Keep only reviewed skills relevant to the task. No marketplace template overrides financial invariants or authorizes a deployment.

## Review evidence — 2026-10-22
Independent source/document spot-check found no material mismatch in keys, relationships, API examples, lifecycle caveats or sandbox boundaries. This is not an exhaustive authorization audit or deployment test. Current run: 21 offline payment-adapter tests and 6 scanner tests pass; working-tree/client-config scanner reports zero findings within its documented scope; `git diff --check` passes. Relative Markdown links were checked. Flutter code was not changed by this documentation pass; prior app-test results are historical.

Six project specialist definitions and three local skills remain available in the repository. Agensi's public MCP API was reached for discovery/review, and `codex mcp get agensi` recognizes the project configuration. Restart/loading inside VS Code still needs confirmation. No marketplace skill was purchased or installed. See [Agensi assessment](../AGENSI_SKILL_REVIEW.md) for candidate fit and [agent workflow](../AGENT_WORKFLOW.md) for responsibilities.

## Database reproducibility evidence — 2026-10-25
The fresh-only profile baseline, all 11 feature migrations and all 10 rollback SQL
suites passed in the documented PGlite platform fixture. The lockfile also passed
an offline `npm ci --ignore-scripts` reinstall. Six scanner tests passed and the
working-tree/client-config scan reported zero findings within its scope.
Independent review found no material baseline authorization issue. The engineering
workflow now includes this database check; hosted CI execution is not yet verified.

No deployed migration was changed and no live database was accessed. The fixture
does not establish exact hosted schema parity, full Supabase integration,
concurrency, or recovery guarantees. These remain explicit next verification steps.
See [runner instructions and limitations](../../supabase/testing/README.md).

## Full-stack verification work — 2026-10-25
A separate `npm run test:integration` runner and manual CI workflow now prepare a
disposable real Supabase stack with pinned CLI 2.122.0. It is intended to exercise
SQL plus Auth password sign-in and PostgREST profile authorization using real JWTs.
The HTTP target guard is tested; full-stack execution remains unverified while
native service startup is being resolved. It does not establish hosted parity,
Storage byte-upload behavior, group HTTP flows or concurrency. See the
[local integration instructions](../../supabase/testing/README.md).
