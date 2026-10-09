# Contribution tracking and leader review

Implemented and verified on 2026-10-09. Migration: `202610090001_contributions.sql`, applied to the matching Supabase project.

## How members use it

Open an active group and select **Track my contributions**. Choose the contribution period. Transfer money outside the app using the payment details already agreed with the group, then use **Record my payment** to enter the transfer reference and the date paid. The amount is fixed to the agreed full contribution. AjoPay does not execute the transfer or independently verify it.

A weekly contribution may be recorded on any of the seven calendar days ending on its scheduled date. These are group-specific windows, not necessarily Monday–Sunday. A Sunday deadline means Monday–Sunday is open. The first period opens six days before its deadline, but the group must already be active. Subsequent windows begin the day after the previous deadline. Daily periods have one calendar day; monthly periods begin after the previous deadline (the first opens one calendar month before its deadline, plus one day). Server dates use Africa/Lagos.

Future windows cannot be submitted. Overdue periods remain selectable and can be reported late; they do not cover a different period. Paying an overdue obligation and the current obligation in the same week is allowed, each with its own record and transfer reference. Partial payments and prepaying future periods are outside this version.

## How leaders use it

Select **Review group payments**, choose the period, and inspect each member's report. Confirm only after checking the actual receiving account. Use **Return for correction** with a reason if the reference cannot be matched. Pending and returned reports do not count toward the confirmed total. The shortfall stays visible.

The leader is also a contributing member and records their own payment separately. The leader can manually confirm their own payment; the dialog discloses this and the actor is stored in the audit history. There is no independent bank or second-reviewer verification.

Refresh to see another account's updates. This version does not use real-time subscriptions. Confirmation is final in this interface; disputed confirmed payments need a future audited correction process, not direct database edits.

## Integrity and privacy

- One ledger row per group, period, and member. A returned report is corrected in place with a new submission version; history remains append-only.
- Repeated identical submissions and review decisions return the current state without duplicating totals or events. Concurrent operations serialize on the group row.
- Review targets a specific submission version. A stale decision cannot confirm a corrected report.
- Only the group leader reviews. Members submit only for themselves; identity is derived by the server.
- Members can read only their own payment references/history. Leaders can read reports for their group. Other users and anonymous clients cannot access the tracker.
- Tables have RLS enabled and no direct client read/write grants. Narrowly scoped RPCs validate authorization.
- Do not enter card details, passwords, or PINs. Receipt image/file uploads are not implemented; current evidence is a transfer reference plus the paid date.

## Verification and manual acceptance

`supabase/tests/contributions.sql` passed in the live SQL Editor with synthetic accounts and transaction rollback. It covers early payment at the opening boundary, future/invalid date and amount rejection, duplicate prevention, non-leader review denial, mandatory rejection reason, correction versioning, stale review rejection, confirmed-record immutability, overdue payments, reused references, member/outsider privacy, direct-write denial, anonymous access, and exact audit-event counts.

Flutter checks cover the member and leader screens, the record/return/correct/confirm flow, retry recovery, narrow layouts and keyboard, request contracts, and date/status/total calculations. Mobile previews use fake data. This does not claim an end-to-end run on two physical devices.

With your two accounts:
1. Join the same weekly group, confirm terms as both users, and activate as leader. Choose a deadline whose seven-day window is already open.
2. As member, open Track my contributions and record a payment only after making the external transfer. Expect Awaiting review and no duplicate submit button.
3. As leader, open Review group payments, refresh, and match the reference against receipt of funds. Confirm receipt or return with a reason.
4. As member, refresh to see Confirmed by leader, or correct the returned record and resubmit.
5. Check the leader's total changes only after confirmation and that selecting a future period offers no record button.

For a demonstration without moving money, use a clearly identified demo group and synthetic references, separate from any real payment records.
