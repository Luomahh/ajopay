# AjoPay competition handoff for Gemini

**Prepared:** 18 November 2026  
**Repository:** https://github.com/Luomahh/ajopay  
**Default branch:** `main`  
**Purpose:** A short, safe handoff for an AI coding assistant preparing a reliable live demonstration under a strict two-hour build window.

> Read this document together with the current source code. Source code and the newest migrations are authoritative. This document is a snapshot, not proof that the app currently builds on a new machine or that hosted services are healthy.

## 1. Product summary

AjoPay is a Flutter application for coordinating Nigerian ajo/esusu savings circles. It helps a group agree on savings rules, invite and onboard members, record externally made contributions, review payment evidence, communicate, track payouts and retain a history.

It supports two savings modes:
- **Rotating ajo:** members contribute to a shared pot and receive scheduled turns according to an agreed rotation.
- **Target / end-date savings:** members contribute toward an agreed end date and receive their own confirmed principal; no interest is generated.

AjoPay's differentiator is the coordination, accountability and traceability around informal group savings. It is not currently a bank, wallet, investment product, escrow service or payment processor.

## 2. Verified repository facts

- Flutter / Dart application; package name `ajopay`.
- Dart SDK constraint: `^3.12.2`. README records Flutter 3.44.6 as the toolchain used for a prior verification.
- State management: Riverpod (`flutter_riverpod`, generated annotations).
- Navigation: GoRouter.
- Backend: Supabase Auth, PostgreSQL, Row Level Security and server-side RPC functions.
- UI: emerald/forest green visual system, Lato fonts, responsive layouts.
- Money is stored as integer kobo, with NGN display formatting.
- Main source areas: `lib/features`, `lib/domain`, `lib/data`, `lib/app`, `lib/core`.
- Backend source: `supabase/migrations`, `supabase/functions`, `supabase/tests`.
- Automated Flutter tests live under `test/`; local SQL/PGlite and integration harness documentation lives under `supabase/testing/`.
- Root guidance: `AGENTS.md`; system design: `docs/system-design/README.md`; workflow: `docs/AGENT_WORKFLOW.md`.

## 3. Features present in the source / documented as implemented

Treat each as implemented in source, not automatically verified on the competition device.

1. Email/password sign-up and sign-in, Supabase session handling, sign-out and contact-details completion.
2. Group draft creation, invite-code joining, member agreement/consent and group activation.
3. Configurable savings mode, contribution frequency, payout schedule, member limit and agreed group terms.
4. Group member and details views, including leader-provided bank account details for members to use when making external transfers.
5. Contribution reporting with reference, payment date, optional screenshot and note.
6. Leader review: confirm or return a contribution report for correction; pending/returned reports do not count as confirmed funds.
7. Rotating and target savings payout tracking, leader payout record, recipient acknowledgement, problem report/dispute, correction history and completed-round state.
8. Member-only group text chat with periodic refresh.
9. Member profiles with controlled phone sharing and owner-only home address.
10. In-app notification inbox and reminder preferences; external email/SMS delivery worker is not implemented.
11. PDF payment statements with date range and role-based record scope.
12. Responsive landing page and dashboard.

Useful existing documentation:
- `docs/DEMO_GUIDE.md`
- `docs/CONTRIBUTIONS.md`
- `docs/PAYOUTS.md`
- `docs/RECEIPTS_AND_CHAT.md`
- `docs/FLEXIBLE_SAVINGS.md`
- `docs/GOOGLE_AND_STATEMENTS.md`
- `docs/NOTIFICATIONS_SETUP.md`
- `docs/SECURITY_CHECKS.md`

## 4. Critical limitations — do not misrepresent these

- **No live payment integration is connected.** Users make transfers externally; AjoPay records reports and acknowledgements.
- A leader confirming a report and a recipient acknowledging a payout are workflow records, not independent bank settlement verification.
- The Paystack adapter under `supabase/functions/_shared/payments/` is an isolated, test-only server-side foundation. It has no public Edge Function, Flutter integration, live credentials, or ledger credit path.
- No live wallet, custody, automatic collection, automatic payout, virtual account provisioning, or provider reconciliation is implemented.
- KYC / NIN / BVN verification is not implemented. Do not add raw identity-number fields or fake verified badges.
- Late fees may be assessed/displayed according to group rules but are not collected or settled.
- Google sign-in is present but disabled until provider configuration and real callback testing are completed.
- External email/SMS notification delivery is proposed; the in-app notification inbox exists.
- Fresh-project database bootstrap and hosted migration-history/schema parity need care. Existing migrations were applied manually to the configured Supabase project. **Do not replay migrations against that hosted project.**
- Existing release APK configuration uses a development/debug signing key; it is not Play Store production signing.

Never put a Supabase service-role key, payment secret, OAuth client secret or personal token in Flutter assets, `.env`, Git, screenshots or chat. Flutter's bundled `.env` is public at runtime; it may contain only the public Supabase URL and anon/publishable key.

## 5. Architecture and conventions to preserve

- Keep Flutter + Riverpod + GoRouter + Supabase. Do not rewrite state management or navigation.
- Keep backend-independent entities and repository contracts in `lib/domain/`; implementations in `lib/data/`; feature providers/controllers between presentation and data.
- Do not add raw Supabase queries to new widgets when an existing repository boundary is appropriate.
- Use typed `Result` / `Failure` patterns already used by the project.
- Keep money as integer kobo at every calculation and persistence boundary; format as naira only for display.
- Derive permissions, contribution amounts, recipients and legal state transitions on the server. A disabled/hidden button is not authorization.
- Preserve RLS, member/leader privacy, immutable evidence/history and retry-safe operations.
- Keep demo/synthetic records separate from actual group records.
- Do not alter unrelated working features or perform broad dependency upgrades under the time limit.

## 6. First actions Gemini must take

Before editing:
1. Read `AGENTS.md`, `docs/system-design/README.md`, `docs/DEMO_GUIDE.md`, relevant feature docs and the newest migrations.
2. Inspect the actual current branch and working tree. Preserve uncommitted work; do not reset, clean, rebase or overwrite user changes.
3. Inspect `pubspec.yaml`, `lib/main.dart`, router, dashboard, group, contribution, payout, chat and notification implementations.
4. Inspect CI status and determine whether it relates to the current HEAD. Historical green checks are not current validation.
5. Run baseline commands where the environment permits:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
   - `flutter build web --release` (if web is part of the demonstration)
   - `python3 -m unittest discover -s scripts -p 'test_security_check.py'`
   - `python3 scripts/security_check.py`
   - `git diff --check`
6. Report exact failures before attempting fixes. Do not claim a command passed unless it was run in this checkout.

## 7. Two-hour competition build priorities

The aim is a robust, easy-to-explain demo, not a large speculative feature set. Choose the smallest high-value slice after inspecting current functionality.

### Priority A — must work
- App launches reliably on the actual demonstration device/browser.
- Authentication works, or a pre-created demo account/session can be used without weakening production auth.
- Dashboard loads with understandable empty/loading/error states.
- A user can open a clearly labelled DEMO savings group and understand the savings rules.
- Member contribution report and leader review flow are demonstrable with synthetic demo references/evidence.
- Payout tracker communicates scheduled recipient, amount, readiness and acknowledgement state.
- Navigation, refresh, back button and sign-out do not strand the user.
- No action claims that money moved when it did not.

### Priority B — high demonstration value, only if A is stable
- A guided demo walkthrough / sample-data seeding path that is explicitly marked DEMO and cannot write into real groups.
- Better dashboard summary: active groups, next contribution deadline, confirmed vs pending contributions, next payout and unread activity, using existing data/providers.
- Search/filter transaction history if a safe implementation is small.
- Clear visual status chips for pending, confirmed, returned, disputed and completed states.
- A polished transaction/payout receipt view based only on recorded workflow state, with a visible “External transfer recorded — not bank-verified” disclaimer.

### Defer
- Real payment gateway integration, wallet balances, virtual accounts, KYC, automatic transfers, live push/email/SMS delivery, credit scores, interest, investment returns, late-fee collection, broad redesign, dependency migrations and new infrastructure.

## 8. Two-hour execution schedule

- **0–15 min:** inspect branch/status, install dependencies, run analyze/tests, identify one blocker.
- **15–35 min:** fix only launch-critical or demo-path blockers.
- **35–75 min:** complete one coherent end-to-end demo journey using existing backend contracts or a strictly isolated demo repository.
- **75–95 min:** improve dashboard clarity and state feedback; ensure mobile responsiveness.
- **95–110 min:** run targeted tests, analyze, build the actual demo target and manually rehearse.
- **110–120 min:** freeze scope, prepare backup account/device/build and a 60–90 second explanation.

If the full suite is slow, run targeted tests first, then the full suite if time permits. Do not sacrifice launch reliability to add another feature.

## 9. Suggested demonstration narrative

1. “AjoPay helps a savings circle agree on rules and keep every member accountable.”
2. Show a DEMO group with member count, contribution amount, frequency, savings mode and agreed schedule.
3. Show a member submitting an external contribution reference (and optional sample receipt).
4. Switch to the leader view and review/confirm or return the report. Explain that only confirmed reports count in group totals.
5. Show payout readiness, record a clearly labelled demo payout, then acknowledge it from the recipient account.
6. Show the history/chat/notifications and explain the auditability and privacy boundaries.
7. State clearly: “This version coordinates and records external transfers; it does not itself hold or move funds.”

Use two accounts if possible. Do not alter real group dates, invent settlement, or use real member/payment data in the demo.

## 10. Gemini master instruction

You are the senior Flutter/Supabase engineer continuing the existing AjoPay repository for a time-limited NYSC innovation/product competition.

Repository: https://github.com/Luomahh/ajopay

Read this handoff and the repository's AGENTS.md and docs/system-design/README.md first. The source code and newest migrations are the authority. Do not assume this document or historical test reports reflect the current working tree.

Your mission is to make the existing app launch reliably and demonstrate one complete, coherent, clearly labelled DEMO savings-group journey in no more than two hours of focused work.

NON-NEGOTIABLE RULES:
- Inspect before editing. Check git status and preserve all existing user changes.
- Do not replace the architecture, rewrite the app, or upgrade dependencies broadly.
- Do not invent APIs, database columns, migrations, environment variables or features. Trace current contracts first.
- Do not replay existing Supabase migrations or change the hosted database without explicit approval.
- Do not connect live payments or claim money has moved. Keep external transfer records distinct from verified settlement.
- Do not add secrets, service-role keys, provider keys, raw BVN/NIN, or fake KYC.
- Never weaken RLS, authorization, validation, idempotency or privacy for demo convenience.
- Synthetic/demo data must be unmistakably labelled and isolated from real user/group data.
- Do not commit, push, deploy, publish or modify hosted infrastructure unless explicitly asked.

WORKFLOW:
1. Summarize the architecture, current status, runnable target, baseline errors and top three demo risks.
2. Propose a minimal ordered plan with files to change and acceptance criteria. Start with launch blockers.
3. Implement one small vertical slice at a time. Keep changes reviewable.
4. Add/update tests for every changed behavior. Use fake repositories for demo-only UI state if needed; do not build a second production data path.
5. Run flutter analyze, relevant flutter tests, full flutter test if time allows, and build the exact target (web or Android). Run the security checks and git diff --check when feasible.
6. Review the diff for regressions, financial misrepresentation, access-control changes, secrets and accidental data leakage.
7. Report changed files, exact commands/results, manual checks still required, and how to launch/rehearse the demo.

DEFINITION OF DONE:
- The app launches on the intended demo target.
- The primary DEMO journey works end-to-end without manual database edits during judging.
- Every action has a visible loading, success or recoverable error state.
- Demo records cannot be confused with real money or real users.
- No critical tests/analyzer/build errors remain unreported.
- A backup demo path and concise explanation are ready.

Begin with repository inspection and a read-only audit. Do not start by redesigning screens or adding payment processing.