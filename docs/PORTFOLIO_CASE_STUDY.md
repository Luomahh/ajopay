# AjoPay — portfolio project summary

**Status:** working personal project and private Android demo; not a production financial service.

## Problem

Ajo/esusu groups need a clear shared record of savings terms, contributions, payment evidence, payout order, and receipt of funds. Messages and transfer screenshots alone make it difficult to know which obligation a payment covers or whether a payout was acknowledged.

## Solution

A Flutter app where a leader creates a rotating or end-date savings plan, members join and agree to its terms, and the group tracks contributions and payouts. Members can add private payment screenshots and notes, leaders review reports, and recipients acknowledge payouts or report problems. Each group also has text chat.

## Engineering decisions to explain

- Riverpod and a stable GoRouter manage session-aware screens without rebuilding navigation on every auth event.
- Repository contracts separate Flutter UI from Supabase implementations and support isolated regression tests.
- Amounts use integer kobo; the server derives payout amounts and recipients from frozen schedules.
- Supabase RPCs enforce membership and roles. Row-level security and revoked direct grants protect payment records.
- Group-row locks, unique constraints, and submission versions protect against duplicate retries and stale reviews.
- Payment images use private storage and short-lived signed links; member and leader notes are separate from review decisions.
- A group completes only after all scheduled recipients acknowledge their payouts. History remains available afterward.

## Verified evidence

- 73 automated Flutter tests passing; clean static analysis.
- Successful web and Android builds; Android emulator startup verified.
- Live rollback-only SQL regression suites for group lifecycle, contributions, receipt/chat privacy, and payout completion.
- Developer confirmed contribution, screenshot/chat, and leader/recipient payout flows with test accounts.
- Private demo APK and fictional-data screenshots available; no production adoption or usage metrics claimed.

## Suggested CV project entry

**AjoPay — Flutter / Dart / Riverpod / Supabase (personal project)**

- Developed an ajo/esusu coordination app with group agreement, daily/weekly/monthly contribution schedules, private payment evidence, leader review, group chat, and recipient payout acknowledgement.
- Implemented server-enforced authorization, integer-kobo accounting, versioned corrections, and retry-safe transaction flows with preserved audit history.
- Added 73 Flutter regression tests and live transactional SQL authorization checks; produced Android and web demo builds.

Use these as project bullets, not employment experience. Be ready to explain and demonstrate the implementation and acknowledge the development tools used.

## Boundaries and next work

AjoPay records external transfers; it does not hold money, process payments, verify bank settlements, or promise investment returns. Before public release, finish physical-device/offline/session testing, resolve demo hosting and account access, configure production signing, and set an evidence-retention policy. Push notifications, production operations, automated payments, bidding, and trust scoring are outside the current demo scope.
