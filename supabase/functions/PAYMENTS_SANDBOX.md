# Paystack sandbox adapter — prepared, not connected

Status: isolated server-side adapter with offline tests. No Paystack account, credentials, public Edge Function, database migration, bank account issuance, UI payment button or live connection is supplied by this change. Existing external-transfer tracking remains unchanged. This is not an end-to-end payment integration and it is not a custody or savings product approval.

## What exists

`_shared/payments/paystack_sandbox.ts` exposes `PaystackSandbox.initialize`, `verify` and `verifyWebhookSignature`. The adapter uses standard Web APIs compatible with Deno; offline tests use Node 24's TypeScript stripping. It rejects live keys and non-test configuration, uses a fixed API host with redirects disabled, validates integer kobo, and verifies reference, amount, NGN currency, customer email, test domain, successful status and safe provider transaction ID. It returns verification evidence only; it never posts money to any balance. IDs outside JavaScript's safe integer range are rejected rather than rounded.

Initialization creates hosted checkout, not a dedicated group virtual bank account. Supported channels depend on the provider account. Account provisioning and pooled-fund custody require separate provider agreement and design.

Webhook validation uses HMAC SHA-512 over exact raw bytes through native Web Crypto verification. A valid signature proves origin, not freshness or entitlement. Duplicate valid events remain valid signatures: the future event inbox and ledger must enforce uniqueness. Never credit directly from a webhook payload. Parse only after signature verification, accept relevant event types, resolve a durable expected intent, then independently verify against the provider. Live-domain transactions fail verification.

Errors expose fixed codes only. Do not log request headers, provider bodies, customer information or secrets. Network errors/timeouts are ambiguous: initialization may have succeeded remotely. Do not blindly retry with a new reference; recover the same intent/reference first.

## Offline check (no account or network needed)

From the repository root, with Node 24:

```sh
node --test supabase/functions/_shared/payments/paystack_sandbox.test.mjs
```

The 21 tests include a mocked initialize-to-verify sequence, forged/altered signatures, mismatched payment details, live-mode rejection, invalid amounts, malicious checkout URL, provider errors and request timeout. Every transport is injected; no request goes to Paystack. Mock success is not a confirmed payment or ledger credit. Node runs these tests; Deno runtime deployment/type-check has not been performed.

## Required before connecting Flutter or a provider account

1. Resolve the provider-approved business model, settlement/custody arrangement, fees, reversals and default policy. Hosted checkout alone does not lock savings until maturity.
2. Add durable payment intents with server-generated unique references and member/group/period ownership. Derive the payable amount and trusted email server-side. Never pass client-supplied financial truth to this adapter.
3. Add authenticated, authorized and rate-limited initialization/status endpoints. Validate membership and active terms. Separate production and test environments; this adapter remains test-only.
4. Add a durable webhook inbox with request-size limits, raw-body verification, event filtering, replay deduplication and recoverable processing. Persist before acknowledging accepted events.
5. Add an append-only balanced ledger and transactionally unique provider transaction postings. Prevent one provider payment being allocated to two intents. Keep test data wholly separate from real contribution records.
6. Add reconciliation, retry jobs, audit records, reversals/refunds, alerting and failure drills. A successful payment does not automatically establish available-to-withdraw funds.
7. Add controlled payouts and identity verification separately. Never collect bank credentials or raw BVN/NIN in this adapter.
8. Create a provider test account and place its test secret only in server secret storage. Do not paste keys into chat, commit them, bundle them in Flutter, or put them in client `.env` assets. Confirm setup and deployment scope before connecting.
9. Run sandbox contract/end-to-end tests against the real test API with explicit authorization. Offline fixtures establish our boundary logic, not provider approval or actual API compatibility.

## Official references

- [Initialize and verify transactions](https://paystack.com/docs/api/transaction/): API operations, amount subunits, unique references and response shapes.
- [Verify payments](https://paystack.com/docs/payments/verify-payments/): server-side confirmation before delivering value.
- [Webhooks](https://paystack.com/docs/payments/webhooks/): signature header and SHA-512 authentication.

Reviewed for this implementation on 2026-10-16. Runtime-specific SDK/package dependencies are intentionally absent.
