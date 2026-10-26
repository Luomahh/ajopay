# 5. Decisions, trade-offs and extensions

These compact decision records distinguish retained implementation from intended work.

| Decision | Reason and consequence | Reconsider when |
|---|---|---|
| Retain Flutter/Riverpod/GoRouter (implemented) | Shared responsive UI; async state/dependency injection already used. Local widget state suits ephemeral UI. A Bloc rewrite adds migration cost without a demonstrated requirement. | Specific lifecycle/performance problems cannot be resolved within existing patterns |
| Retain Supabase/PostgreSQL (implemented) | Transactions, constraints and RLS close to data; fewer operated services. Vendor dependency and SQL testing/migration discipline matter. | Compliance, isolation or measured capacity needs exceed supported platform capabilities |
| Keep external tracking while payments are isolated (implemented) | Avoid falsely treating reports as settlement. Adapter can be tested without financial side effects. | End-to-end verified payment controls and approved provider arrangement are ready |
| Hosted checkout per intent first (proposed) | Clear member/group allocation; avoids ambiguous permanent-account funding. Does not provide custody or automatic payout controls. | Provider supports approved per-member accounts and explicit allocation/wallet design |
| Double-entry ledger and durable inbox (proposed) | Auditable corrections, balance invariants and duplicate prevention. More complexity, justified before real money. | Required for payment system; do not replace with mutable counters |
| Polling initially (implemented) | Simple recovery and bounded pages; high request/fan-out costs with concurrency. | Measured polling load warrants subscription transport with reconnect/catch-up and authorization |
| No Redis/microservices yet (decision) | Avoid distributed invalidation and operational overhead before evidence. | Traces/load tests show a specific bottleneck and simpler optimizations fail |
| Agensi for optional skill discovery (workflow) | User preference; inspect provenance, license, instructions and scripts. Discovery is not trust or installation authorization. | A reviewed task-relevant skill is unavailable; author a minimal local alternative |

## Prioritized implementation plan
1. **Reproducibility and safety:** capture baseline profiles/auth schema, compare hosted migration history, build isolated database setup, run denial tests and scanner. Local prerequisite and platform fixture are now versioned under `supabase/bootstrap` and `supabase/testing`. Remaining acceptance: disposable full Supabase rebuild, reviewed hosted schema/migration reconciliation, no secrets in client artifacts.
2. **Product contract:** agree prolonged-default/grace/cancellation policy; distinguish locked-full from activation; controlled recovery and recipient-bank changes; reconcile target shortfall behavior. Acceptance: state/permission table, scenarios and explicit user decisions. Do not fabricate unresolved decisions.
3. **Date/API consistency:** unify Lagos calendar rules; formalize typed request/response/error contracts; paginate histories; move direct feature queries behind repositories progressively. Acceptance: timezone boundary tests, cursor tests, stable old-client behavior.
4. **Payment persistence foundation:** isolated sandbox database intent/inbox/ledger schema with uniqueness and balanced atomic postings; no live keys. Acceptance: concurrent duplicate/out-of-order/unknown-result tests and tenant isolation.
5. **Authenticated sandbox endpoints:** connect existing adapter to server-derived intents and signature-verified durable event processing, authorization/rate limits, status API and clearly labelled Flutter test flow. Acceptance: test data cannot credit real contribution records; runtime type-check/deployment tests. Account setup is external prerequisite for actual provider tests.
6. **Reconciliation and payout design:** unknown outcomes, refunds/reversals, reserves, payout beneficiary controls and operational dashboards. Acceptance: replay/failure/recovery drills, verified available funds and immutable audit history.
7. **Provider/business approval and identity:** agree custody/settlement, KYC, supported collection accounts, fees and dispute process; consent/minimized verification data. Acceptance: approved arrangement and explicitly authorized sandbox end-to-end checks. No raw BVN/NIN collection merely for appearance.
8. **Measured pilot readiness:** performance/load budget, backup restore, security review, accessibility/devices, support/incident procedure. Acceptance: evidence against the objectives, then a separately approved limited live rollout.

## Agent workflow
Planner drafts requirements and acceptance; backend and Flutter specialists receive bounded file ownership; security/reviewer examines the diff independently; orchestrator integrates and reports actual evidence. DevOps owns reproducible checks and environment/deployment plans, not unconditional production access. Scanner automation supplements a security reviewer. Small tasks need no delegation overhead.

Relevant local skills should cover Flutter delivery, Supabase migration/security verification and release review. Keep only skills with an actual recurring use. Agent/skill definitions describe responsibilities; they do not create autonomous guarantees, provision infrastructure or authorize publishing. See `AGENTS.md` and `docs/AGENT_WORKFLOW.md` for the operational instructions.

Extensions after the baseline: realtime chat, durable external reminders, approved virtual accounts, stronger account recovery, controlled KYC and public hosting. Investment returns, credit/guarantees and automated late-fee collection remain outside the initial payment release.
