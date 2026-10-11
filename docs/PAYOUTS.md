# Payout recording and recipient acknowledgement

Implemented on 2026-10-10 and finished on 2026-10-11. Migration `202610100002_payouts.sql` is already applied to the current Supabase project. Do not rerun it there.

## How to use it

Open a group and select **Track payouts**. This screen shows the agreed recipient, amount, payout date, contribution shortfall, and payout status. Refresh to see another account's actions.

For rotating ajo, every contribution in the selected period must be confirmed, the agreed payout date must have arrived, and every earlier recipient must have acknowledged receipt. The amount is the full agreed pot. Later contribution periods still follow the frozen schedule: receiving a payout does not remove a member's future obligations.

For end-date savings, every scheduled contribution across the group must be confirmed and the agreed end date must have arrived. Each member receives their contribution amount multiplied by the number of scheduled contributions. No interest is added. Each member's payout is recorded and acknowledged separately.

The leader transfers money outside AjoPay, then selects **Record payout**, enters the transfer reference and paid date, optionally adds a note, and confirms that the full amount was already sent. Recipient and amount are fixed by the server. A form retry never moves money; check the existing transfer rather than sending it again.

The recipient refreshes, checks their receiving account, selects **I received this money**, and explicitly confirms receipt of the full amount. Alternatively, **Report a problem** requires a reason. A disputed payout blocks progression to later rotating payouts until resolved. The leader may correct a disputed record; the recipient may also confirm the same record if a delayed payment arrives. Every submission, correction, dispute, and acknowledgement is retained in history. Final acknowledgement cannot be reversed through this interface.

A leader who is the scheduled recipient acknowledges their own payout. The confirmation dialog discloses this, and the actor is stored in the history; this is not independent verification.

When every scheduled recipient has acknowledged receipt, the group becomes **completed**. Contribution and payout history remain readable. A new round requires a new group with newly agreed terms; the app does not automatically renew obligations.

## Privacy and integrity

- Members see group-wide recipient names, scheduled amounts, aggregate confirmed contributions, and payout statuses.
- Transfer references, paid dates, notes, and detailed history are limited to the leader and the relevant recipient. Outsiders and anonymous clients cannot read the tracker.
- RLS is enabled; direct client reads/writes on payout and history tables are revoked. Authenticated RPCs enforce identity, frozen terms, funding, dates, order, and submission version.
- Recording and acknowledgement serialize on the group row. Identical retries return current state without duplicating records or history, including after completion. Stale acknowledgements cannot confirm corrected records.
- Pending/disputed payouts do not contribute to the amount confirmed received. Unconfirmed contributions never make a payout ready.
- No partial payouts, default write-offs, automated transfers, investment returns, or bank verification are included. Payout screenshots are not part of this version; contribution screenshots remain available in contribution review.

## Verification

`supabase/tests/payouts.sql` passed live on 2026-10-10. It creates synthetic historical rounds inside a rollback-only transaction and checks both savings modes, full-principal amounts, shortfalls, future dates, payout order, role restrictions, private details, disputes, correction versions, duplicate references, retries, completion, and retained history. No real group records or money were changed by these tests.

Flutter tests cover request contracts, typed failures, retry recovery, member/leader actions, explicit acknowledgement, required problem reasons, completed views, totals, and a narrow screen with a keyboard. Mobile screenshots were reviewed with fake data.

Manual acceptance with two accounts:

1. Use a clearly labelled demo group. Wait until its scheduled payout date and confirm every required contribution.
2. As leader, open **Track payouts** and record a clearly identified demo transfer without moving money.
3. As recipient, refresh and report a problem; as leader, refresh and correct the reference.
4. As recipient, refresh and confirm the corrected demo record. Check the preserved history.
5. Complete the remaining scheduled payouts as their dates arrive. Confirm that the group becomes completed only after the last acknowledgement and retains its history.

Use a demo group for simulated records. For real groups, record only actual transfers and acknowledge only funds actually received. On 2026-10-11 the developer confirmed that the payout flow worked from both the leader and recipient accounts. Individual dispute/correction branches were covered by automated tests; a physical-device walkthrough remains part of release acceptance.
