# Flexible savings, profiles and group bank accounts

Implemented on 2026-10-11. Release packaging remains paused.

New drafts use rules version 2. Existing drafts and active/completed groups keep rules version 1, their original contribution/payout schedules and zero late fee. Create a new draft to try the new rules; existing accepted agreements are not rewritten.

## Savings rules

- Rotating ajo: exact contribution amount, separate contribution and payout frequencies. Payouts may be as frequent as contributions or slower. Each payout includes deadlines after the previous payout and on/before its own date. Five weekly deadlines produce a different pot from four; the agreed preview shows each recipient, date, deadline count and expected amount. All required contributions must be confirmed, and the previous payout acknowledged.
- End-date savings: amount is a minimum per period. One payment report may exceed that minimum, up to NGN 1,000,000. Underpayments are rejected by the server. Each member's final entitlement is their actual confirmed principal, with no interest. Extras never fulfil another member's obligation.
- A member still submits one report per contribution period. Rejected reports can be corrected; this is not a split-payment or unlimited top-up wallet.
- Late fee: NGN 200 once per missed deadline from the following day in Africa/Lagos time. On-time transfers reviewed later incur no fee after their payment date is confirmed. Pending/absent/rejected reports display a provisional fee awaiting date review. Fees are derived per member/period, never added to contribution principal or deducted from payouts. **No fee collection or settlement exists yet.** The UI tells members not to transfer fees into the savings account.

## Group account and profiles

Leaders add an existing bank name, account holder name and 10-digit account number inside a draft. Group members can view/copy the account. Changes reset consent and increment the terms version; activation locks the account. New groups require bank details to activate. AjoPay does not create or verify this account. Verify the recipient name through the bank before transferring.

Profiles contain a shared display name, optional city and introduction, plus a required contact phone that is private unless the owner opts in to group sharing. Fellow members can open a shared profile from the member list. RLS keeps the full profile and home address owner-only; the group-scoped profile RPC returns only shared fields.

Identity verification is **not implemented**. There is no raw NIN field, upload, self-issued verified badge or numerical trust score. Provider-backed NIN verification and a server-enforced payment gate are required before launching in-app payments. Manual external-payment recording remains available for this prototype.

## Verification and deployment

Migrations:
1. `202610110001_profiles_and_group_accounts.sql`
2. `202610110002_flexible_schedules.sql`

`supabase/tests/flexible_schedules.sql` tests new draft retries, calendar weeks, amount bounds, actual principal payouts, fee separation, RLS, account consent/locking and shared-profile privacy. The five earlier SQL suites remain regression coverage for old groups. Fixtures roll back.

The local PostgreSQL-compatible PGlite run uses minimal auth/storage fixtures; live Supabase verification remains necessary to check actual grants and signup triggers. See the delivery plan for the recorded live result. Do not reapply a migration already applied manually. Reconcile Supabase migration history before enabling automated deployment from GitHub.

## Remaining payment work

The owner does not yet have a payment-provider merchant account. An existing leader-supplied group account works for manual external transfers. Automatically provisioning an account per group, bank account ownership checks, secure identity verification, webhook reconciliation, refunds/disputes and collection of platform fees require provider onboarding and approved API access. Never embed provider secrets in Flutter or accept a browser-supplied payment status as settlement evidence.

Provider references reviewed: [Paystack dedicated virtual accounts](https://paystack.com/docs/payments/dedicated-virtual-accounts/) and [Flutterwave NGN virtual accounts](https://developer.flutterwave.com/docs/ngn-virtual-accounts). Account-per-group provisioning must be confirmed with the chosen provider; customer account APIs should not be assumed to support pooled group custody automatically.

Contact update (2026-10-12): phone is required for onboarding and remains private unless its owner enables group sharing. Home address is always owner-only. Phone numbers are self-reported, not verified. BVN/NIN are not collected.
