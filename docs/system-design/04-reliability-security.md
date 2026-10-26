# 4. Scale, failures and security

## Failure analysis
| Failure | Existing protection / next action |
|---|---|
| Duplicate group create/chat send | Implemented request IDs and uniqueness; keep stable IDs across retries |
| Last group slot claimed concurrently | Join path locks group; test concurrency against real PostgreSQL, not only sequential fixtures |
| Concurrent payment report/review | Implemented versions and transactions; stale clients refresh |
| Network loss after commit | Existing idempotent paths recover matching requests; future payments must recover persisted reference before retry |
| Duplicate/out-of-order webhook | Proposed durable inbox, authoritative verify and unique ledger transaction; signature alone does not stop replay |
| Receipt upload succeeds but submission fails | Proposed orphan reconciliation and retention; never delete evidence still referenced by history |
| Provider payout times out | Proposed unknown state; query/reconcile before retry, retain reserved funds |
| Database/region outage | Current single managed project is dependency; documented backup/restore/failover proof missing |
| Reminder retries | Implemented notification dedupe; future delivery claims/retries/idempotency required |
| Failed member after receiving rotating payout | Unresolved business default policy; fee does not recover principal |
| Service account compromise | Limit secrets and privileges, rotate credentials, audit; design incident isolation before live payments |

Known date gap: activation/date checks use UTC/current_date in places while contribution deadlines use Africa/Lagos. Unify business dates explicitly and add boundary tests around 23:00 UTC, month ends/leap years and delayed provider confirmations. Do not silently change accepted schedules.

## Security boundary
Implemented source includes RLS, membership/owner checks, restricted direct writes, private receipt access, expected versions and fixed server search paths. These require ongoing adversarial tests; passing happy-path tests is insufficient. A member's “confirmed” manual contribution is leader-reviewed evidence, not a bank-confirmed balance.

Proposed threat tests: cross-group IDs, guessed invite codes, forged user/amount/recipient fields, oversized uploads/webhooks, replay, duplicate payment allocation, tampered signatures, expired auth, account recovery, revoked membership, logs containing personal data and secrets. Contact fields are not verified ownership. Mask identity references; never present unverified profiles as KYC-complete.

Flutter `.env` assets are public distribution artifacts. Only public project configuration belongs there. Service-role/payment secrets stay server-side and outside Git. Automated scanning is a useful control, not proof that no secret exists; scope history scanning deliberately and rotate any exposed credentials. See `docs/SECURITY_CHECKS.md` and repository scanner.

## Operational work still required
- Define dashboards for API p50/p95/p99, errors, DB locks/connections, storage/egress, polling, queue age and job failures.
- For future payments: unmatched intents, verification failures, duplicate events, reconciliation discrepancy, stuck payout/reserve and ledger balance checks. Alert on financial invariants immediately.
- Use correlation IDs with redacted logs; never log auth headers, raw BVN/NIN, provider secrets or full webhook/customer payloads.
- Establish incident owner, escalation, rollback, provider outage and payment-disable procedures.
- Set backup policy based on approved RPO/RTO and selected tier; restore into an isolated environment, verify data/authorization and document elapsed time. Back up object data strategy separately from database rows.
- Reconcile manually applied migration history with hosted state; obtain existing profiles/auth DDL and baseline before automated fresh installs or deployment pipelines.
- Test schema changes expand/contract; preserve old client contracts during rollout. Do not edit already deployed migration files to repair production.

## Verification gates
Repository tests establish behavior under their fixtures. SQL fixture harnesses can stub auth/storage and therefore do not prove a fresh hosted rebuild or actual storage integration. Offline payment tests do not prove runtime deployment, provider compatibility, custody approval or real payment processing.

Before public demo: run analysis/tests/web build/security checks, rebuild an isolated database from complete migrations, test two-account denial and lifecycle flows, verify responsive/offline/session behavior. Before real money: complete provider arrangement, defaults/withdrawal policy, ledger/inbox/reconciliation, sandbox end-to-end and replay/failure drills, privacy/security review, backup restore and operational ownership. Separate test and production accounts, databases and secrets.
