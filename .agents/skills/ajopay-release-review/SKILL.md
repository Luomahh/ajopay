---
name: ajopay-release-review
description: Review an AjoPay release or substantial change for regressions, secret exposure and release readiness.
---

# ajopay-release-review

Read `AGENTS.md` and `docs/SECURITY_CHECKS.md`. Inspect the current diff independently from its implementation summary. Identify changed trust boundaries and critical user journeys.

Run `python3 scripts/test_security_check.py` and `python3 scripts/security_check.py`; use the documented full-history scanner as a separate check. Keep findings redacted. Check `.env` is limited to public client configuration and ensure server keys cannot be bundled into Flutter.

Review auth/membership, concurrency, retry safety, private evidence and fee/principal separation. Run relevant test suites and check stale historical validation claims. Payment mocks cannot establish provider availability, settlement, KYC or recovery readiness.

Return findings with path/line, reproduction and impact; otherwise state no actionable findings and list untested boundaries. Separate code readiness from deployment authorization. Do not push, publish or move real funds as a side effect of review.
