# 1. Requirements and capacity

## Main use case and users
A leader proposes a savings plan; invited members agree, contribute, track obligations and receive scheduled payouts. A user can lead one group and be a member of another. Current platforms are Flutter Android and responsive web; iOS/device-specific acceptance remains separate. Do not claim browser testing proves every platform works.

Implemented: rotating plans use exact contributions; rules-version-2 target plans accept the minimum or more. Daily, weekly and monthly contribution schedules can differ from supported payout schedules. Rotating payouts use actual scheduled contributions between payouts. Existing groups retain accepted historical rules. Members have private contribution views; leaders review their group's reports. Profiles are not verified identity badges. No funds are held or transferred by the current app.

## Agreed target lifecycle
Proposed product stages: draft → open invitations → full/locked → active → completed. Current SQL statuses are only `draft`, `active`, `completed`; joining/consent/fullness are conditions within draft. Capacity and active-group restrictions exist, but do not describe a separate persisted locked stage as implemented.

Target invariants:
- Leader proposes terms; every member accepts the final version before activation.
- Once full, no replacements, ordinary departures or new entrants; recipient order cannot be switched during the plan.
- Earlier payout recipients retain all later contribution obligations.
- Identity recovery must recover the same person, not substitute a recipient. Fraud/death/legal exceptions require a documented controlled process.
- Proposed provider payouts use verified available funds, never scheduled or merely reported totals.
- NGN 200 is assessed once per missed deadline, separate from principal. Collection is currently paused. Future collection must disclose allocation and handle delayed provider events without penalizing timely transfers.
- Prolonged default, grace duration, group cancellation and terminal shortfall resolution remain unresolved. Membership locking is not a repayment guarantee. Do not enable live rotating payouts until these rules are agreed.

A proposed improvement for target savings is that one member's shortfall should not indefinitely block another's earned entitlement. Current payout rules require group funding conditions: this improvement needs explicit SQL/API changes and tests, not just new wording.

## Scope boundaries
Current: authentication, groups, external-transfer reports, review, receipts, payouts, chat, notifications, PDF history. Proposed: provider payment intents, verified events, ledger, reconciliation, controlled payouts and provider-based identity checks. Out of first payment release: investments/interest guarantees, credit scoring, lending, multi-currency and automatic fee collection. Raw BVN/NIN collection is not a prerequisite for the design; use approved verification requirements and minimize retained data.

## Planning assumptions — not adoption statistics
Pilot model: 1,000 MAU, 200 DAU, 50 ordinary requests/DAU/day = 10,000/day = 0.116 average RPS. Assume 10× ordinary burst = 1.16 RPS, then add polling separately. A provisional 80:20 ordinary read/write ratio means 8,000 reads and 2,000 writes/day; measure rather than claim this ratio is observed.

Chat refreshes about every 5 seconds: 100 open chats add at least 20 RPS. Notification polling every 30 seconds for 100 sessions adds about 3.3 RPS. A provisional 50 RPS mixed-workload benchmark provides room above this scenario; it is not a capacity certification. Include leader deadline bursts, authentication and receipt traffic separately.

Illustrative monthly storage: 10,000 receipts × 500 KB ≈ 5 GB object storage (at the 5 MB upload ceiling, ≈ 50 GB). 100,000 chat messages × assumed 1 KB ≈ 100 MB raw; indexes, metadata and notification fan-out are extra. One message can notify up to 49 other members. Retained months, revisions, backups and download egress multiply costs. Measure actual row/object sizes before purchasing a tier. Retention/deletion periods require product decisions.

## Proposed service objectives
- API p95 ordinary reads <500 ms; writes <1 s, measured at the API boundary, excluding uploads and client-network latency.
- Initial availability objective 99.9% monthly (~43.2 minutes / 30 days). Managed-service tier and operational capability must support this before promising it.
- External-transfer demo recovery objective: RPO ≤24 h, RTO ≤4 h, subject to a demonstrated backup/restore drill.
- Before real money: propose RPO ≤5 min and RTO ≤1 h with provider reconciliation; validate supported backups and business requirements. These are not current guarantees.
- No cross-user private data disclosure; no duplicate logical payment credit; no unbalanced ledger posting. Safety is an invariant, not a percentile goal.
- Responsive 320px–desktop layouts, accessible labels/contrast/text scaling, clear pending/error states and explicit offline behavior.
