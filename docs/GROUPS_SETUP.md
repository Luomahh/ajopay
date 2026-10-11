# Group lifecycle

## Status — 2026-10-08

Creation, invite-code joining, group details, member agreement, and leader activation are implemented. The emerald design is retained. The matching Supabase project has all three migrations applied:

1. `202609240001_draft_groups.sql`
2. `202610070001_savings_modes.sql`
3. `202610080001_group_activation.sql`

The migrations run once and intentionally fail if their objects already exist. Do not rerun them on the current project. For a new database, establish the existing `profiles` table/auth profile trigger first, then apply these migrations in order. Existing profile policies and the auth trigger are unchanged.

## Using the flow

1. Create a draft with a contribution amount, daily/weekly/monthly frequency, member count, and dates. Choose rotating payouts or saving to an end date.
2. The leader is automatically a member. Copy the invite code from group details. Other signed-in users paste it into Join a group.
3. Fill the planned member places. For rotating groups, the leader prepares a random payout order once. Retrying cannot reshuffle it.
4. Each member reviews the terms and schedule, checks the agreement box, and confirms personally. Joining does not count as agreement.
5. Once everyone has agreed, the leader confirms activation. The server saves the schedule atomically and locks out new members. Retrying activation cannot create duplicate periods.

Refresh group details to see new members and agreements. Existing members may reuse an invite to reopen their group. New members cannot join a full or active group. If the start date has passed, create a new draft; editing terms, removing members, leaving, and rescheduling are not implemented.

## Authorization and data

Clients cannot directly modify groups, membership, agreements, schedules, or audit events. Controlled functions derive identity from `auth.uid()`, lock the group while changing its state, validate the terms version, and enforce owner/member permissions. Group details expose fellow members' display names and agreement/order status, not contact details or trust scores. Schedules have membership-scoped read access.

Creation uses a caller-scoped request ID. Joining has a unique membership key and locks the group before capacity checks. Order preparation, agreement, and activation are retry-safe. Terms cannot be edited through the app. Rotating schedules contain one recipient per member; target schedules have no rotating recipient and include due dates through the end date. Monthly dates stay anchored to the original calendar day, clamped for shorter months.

Invite codes are random 32-character values. They are not share links yet. Invite rotation/expiry and dedicated abuse rate limits remain release-hardening work.

## Verification

`supabase/tests/group_activation.sql` was run successfully in the live SQL Editor on 2026-10-08. It uses synthetic auth users in a transaction and rolls all fixtures and changes back. It checks create/join retries, changed-request rejection, capacity, member-only details, RLS isolation, owner-only order/activation, stale and missing agreement rejection, direct-write denial, active-group join denial, anonymous/missing identity rejection, unique rotating recipients, and an inclusive weekly target schedule.

The older `supabase/tests/draft_groups.sql` remains a separate base-function regression script; it was not run during this milestone.

Flutter tests cover creation/join navigation, input validation, error recovery, activation confirmation/retry, role-dependent controls, narrow layouts, session stability, calendar dates, and HTTP request/response contracts. Run `flutter analyze`, `flutter test`, and `flutter build web` from the project root. Client tests use fakes/HTTP fixtures; live SQL tests exercise real database authorization. This milestone does not claim a two-account device walkthrough.

## Contribution milestone — 2026-10-09

`202610090001_contributions.sql` is now applied. Members can record one external payment per contribution period; leaders review it, and members see their own status/history. Weekly windows end on each scheduled deadline. The live contribution SQL suite passed. See `CONTRIBUTIONS.md` for the rules and two-account walkthrough.

## Next milestone

Payout recording and recipient acknowledgement. Receipt-file uploads are also deferred; current payment evidence consists of the transfer reference and payment date. The saved schedule is planning data, not proof that money was received. AjoPay does not collect, hold, transfer, or invest money, and no interest is promised.

## Payout milestone update — 2026-10-11

Group details now opens **Track payouts**, with **View payout history** after completion. Payout recording, recipient acknowledgement, and completed-round history are implemented; see [payouts](PAYOUTS.md). The next step is full-round device acceptance and release polish.
