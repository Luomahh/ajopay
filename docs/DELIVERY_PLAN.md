# AjoPay — recovery and delivery plan

## Objective
Ship a credible Flutter portfolio demo while applying for remote roles that accept applicants based in Nigeria. A 7–14 day hiring target is aspirational; hiring timelines are outside our control. Daily availability and prior professional experience still need confirmation.

## Original inspected baseline
The existing app contains Supabase authentication, Riverpod controllers, GoRouter routes, and a placeholder dashboard. Group screens and business use cases are empty. No SQL migrations were found, and the project folder has no Git repository. Remote database state has not been inspected.

## First repair milestone
- Keep one router instance and refresh redirects on authentication changes; dispose router resources.
- Distinguish sign-up with a session from sign-up requiring email confirmation.
- Show the email-confirmation next step instead of silently remaining on sign-up.
- Show sign-out failures and map retryable authentication failures to network errors.
- Make authentication forms scrollable for small screens and keyboards.
- Replace the obsolete counter test with authentication behavior tests.
- Update the Supabase initialization argument for the installed SDK.

This repairs the authentication foundation; it does not complete the savings product or verify live authentication.

## Product scope
AjoPay coordinates rotating savings for private groups. For example, ten members each contribute NGN 20,000 every month. Each monthly pot is NGN 200,000, and a different member receives it. Every member continues contributing through all ten periods, including after receiving a payout. Pooled contributions are not profit.

Version one records externally made payments and payout acknowledgements. Clearly labelled demo data must be separate from real records. It does not hold funds, automatically transfer money, guarantee repayment, calculate investment returns, or assess creditworthiness.

Ship: authentication, create/join group, member list, agreed payout schedule, contribution evidence, administrator review, payout confirmation, history, and a clear dashboard.
Defer: bidding, numerical trust scores, push notifications, automated payments, multi-currency, and investment returns. The save-until-a-deadline mode was subsequently included at the user’s request.

## Rules to implement
1. Groups have a draft setup stage. Confirm members, amount, dates, and payout order before activation; freeze these terms for the active round.
2. An N-member round ends after N confirmed payouts. Each member is scheduled once; receiving a payout does not remove later contribution obligations.
3. Store amounts as integer minor units (kobo), with explicit NGN currency semantics. Store actual amounts collected and paid separately from scheduled amounts.
4. Separate contribution collection from payout: collecting -> ready for payout -> payout recorded -> recipient confirmed -> completed. Do not generate the next period merely because contribution evidence is approved.
5. A shortfall remains visible and blocks readiness for the scheduled full payout. Marking arrears or a default does not create funds or erase debt. More complex shortfall resolution is outside the first demo.
6. Server operations validate membership, invitation, group capacity, expected amount, status transitions, and recipient eligibility. Never rely on hidden UI controls for authorization.
7. Group activation, contribution decisions, payout finalization, and next-period creation must be transactional and safe to retry. Use unique constraints to prevent duplicate membership, contribution obligations, periods, and payouts.
8. Join through a controlled server function. Do not allow unrestricted self-insertion into a known group ID. Expire/rotate invitations and apply rate limiting to short-code guesses.
9. Lock contributor, group, cycle, and money fields against unauthorized changes. A member cannot submit an already-verified contribution. Use private proof storage and access policies scoped to authorized viewers.
10. Keep an audit history of decisions. Test unauthorized access with multiple users; basic row ownership checks are insufficient.
11. The mobile/web app contains only a publishable/anon client key, never a service-role key. An asset .env is distributed with the app and is not secret storage.

## Implementation approach
Retain the working Flutter/Riverpod/GoRouter/Supabase stack. Add only structures needed for working features. Avoid a dependency upgrade or state-management rewrite just to match a document. Introduce database migrations into source control after comparing with the existing remote schema. Do not overwrite an uninspected database.

## Delivery sequence (provisional)

### Progress on 2026-09-24
- User verified live signup, confirmation email, and successful sign-in to the dashboard. The confirmation link's final localhost redirect still needs deployment/development URL configuration.
- Inspected the remote public schema through the Supabase dashboard: only `profiles`, with RLS enabled, three own-profile policies, and `handle_new_user()`. The group change preserves those objects.
- Implemented the first group slice locally: authenticated dashboard listing, draft creation, exact kobo amounts, monthly pot preview, input validation, error recovery, and stable request IDs for retries.
- Prepared `supabase/migrations/202609240001_draft_groups.sql` for atomic group/owner membership creation, membership-scoped reads, blocked direct writes, and an audit event. Applied live by 2026-10-08; see the current milestone below.
- Prepared transactional SQL authorization checks in `supabase/tests/draft_groups.sql`. They require the migration and have not yet run.
- Next: apply and verify this slice, then controlled invitations/joining, member list and consent to terms, activation, and the payout schedule. This historical next step is now implemented; see below.

### Completed group milestone — 2026-10-08
- Kept the emerald visual style and added member-scoped group details, the member list, explicit savings terms, invite-code copying, and schedule review.
- Creation and joining open group details. Daily, weekly, and monthly contributions work for rotating and target-date savings.
- Rotating order is drawn once after the group fills. Every member explicitly confirms the current terms before the leader can activate.
- Activation atomically persists the agreed schedule; server authorization blocks unauthorized actions, missing agreement, late joining, and direct table mutation.
- All three group migrations are live. The rollback-only lifecycle SQL suite passed against Supabase, including creation/join retry, RLS privacy, agreement, activation, and schedule checks.
- Next: contribution records and payment evidence with leader review, followed by payout recording and recipient acknowledgement. No funds move or earn interest in this app.
- See `GROUPS_SETUP.md` for current instructions and boundaries. Historical baseline notes above describe earlier work, not current feature availability.

### Completed contribution milestone — 2026-10-09
- Members have a personal contribution view; leaders have a per-period payment review list, expected/confirmed totals, and unconfirmed balance.
- Weekly windows run for the seven days ending on the agreed date, using Nigeria calendar time. Members can report early within that window, or report an overdue period explicitly. Future windows remain closed.
- One full contribution per member/period; references cannot be reused across pending/confirmed periods for the same member and group.
- Leader confirmation and return-for-correction preserve an append-only audit history. Corrections use a version check; stale reviews and duplicate submissions are rejected or returned idempotently.
- The fourth migration is live, and `supabase/tests/contributions.sql` passed with all test fixtures rolled back.
- Payment evidence currently means a transfer reference and paid date. Private receipt uploads, automated bank verification, and payment processing are not implemented.
- Next: record payouts and recipient acknowledgement; do not call a scheduled pot actual money collected.

### Completed receipts and chat milestone — 2026-10-10
- Optional PNG/JPG/WebP payment screenshots (5 MB maximum) and member notes, with private leader/uploader access and preserved submission evidence.
- Group text chat with sender names, leader badges, pagination, retry protection, and five-second foreground refresh.
- Fifth migration applied live; rollback-only receipt/chat authorization tests passed. Screenshots are evidence for manual review, not independent bank verification.
- Next: payout recording and recipient acknowledgement.

### Planned milestones
- Days 1–2: finish recovery; establish Git history; inspect Supabase schema and reproduce the original reported error; verify live auth.
- Days 3–5: secure group create/join, membership, activation, and payout schedule.
- Days 6–8: contributions, evidence, review, payout confirmation, and history.
- Days 9–10: authorization tests, edge cases, mobile/web layout, and demo data.
- Days 11–14: demo recording, screenshots, README, release artifact, CV project story, and interview practice.

Android and web are the immediate verification targets. Flutter doctor reports an Android emulator and usable Android tooling. iOS is blocked by incomplete Xcode and missing CocoaPods; do not describe it as verified.

## Employment work alongside development
Start applications before product completion. Target roles that explicitly accept Nigeria, Africa/EMEA, or worldwide applicants; check each listing's location and work-authorization requirements. Include Flutter contract work in the search. Obtain the developer's current CV and past projects before drafting experience claims. Prepare tailored applications and outreach drafts; the developer reviews and sends them.

A provisional daily split is 60% product work, 25% applications, and 15% Flutter interview practice, adjusted when available hours are known. Practice explaining state management, async flows, navigation, repository boundaries, backend authorization, testing, and the product's money-handling rules using the actual code.

## Release evidence
Require clean static analysis, meaningful passing tests, a successful web build, and an Android run/build before calling the demo ready. Verify live sign-up, confirmation, sign-in, sign-out, and session restoration. Test the full savings round and denied cross-group access. Include setup instructions, screenshots, known limitations, and a short walkthrough. Label checks that have not been performed.
