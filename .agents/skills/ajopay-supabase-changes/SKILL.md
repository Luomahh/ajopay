---
name: ajopay-supabase-changes
description: Develop and verify AjoPay SQL migrations, RPC authorization or server-side payment changes.
---

# ajopay-supabase-changes

Read `AGENTS.md`, `supabase/README.md` and the relevant API/data design. Check whether the target migration is already deployed. Add a new migration for changes to deployed schemas.

Map caller roles, direct grants, RLS and SECURITY DEFINER paths. Derive auth identity on the server; qualify objects and constrain search paths. Protect membership, immutable terms, kobo amounts, state transitions, versions and retry keys with transactional enforcement.

Run rollback-only positive and adversarial tests in an isolated test database. Include unauthenticated/nonmember access, another member's private evidence, duplicated requests and stale versions. Do not apply the migration to hosted production just to run a test. Existing historical baseline and migration ledger need reconciliation before automatic deployment.

For provider code, validate raw-body signature and server verification, compare amount/currency/reference/test mode, and durably deduplicate before financial credit. Follow `supabase/functions/PAYMENTS_SANDBOX.md`; an adapter test does not validate custody or live transfers.

Report deployment state and missing infrastructure explicitly. Never print credentials or personal identity records.
