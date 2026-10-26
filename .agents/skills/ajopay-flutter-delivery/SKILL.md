---
name: ajopay-flutter-delivery
description: Implement or refactor AjoPay Flutter features with Riverpod, repository contracts and responsive emerald UI.
---

# ajopay-flutter-delivery

Read `AGENTS.md` from the repository root and the relevant feature contract in `docs/system-design/`. Trace the existing repository/provider/widget boundary. Define visible acceptance states before editing.

Use typed entities and Result/Failure conventions already in the feature. Keep backend calls out of new widgets. Invalidate dependent providers after mutations and isolate identity-scoped state across sign-out. Preserve GoRouter stability during transient authentication errors. Use integer kobo at money boundaries; format only for display.

For payments, display pending until authoritative backend confirmation; screenshots and client callbacks do not credit funds. Keep current transfer reporting distinguishable from future integrated payments.

Run relevant widget/repository tests, static analysis and responsive checks for changed layouts. Report observable behaviour, validation and remaining limits. Avoid adding tests that merely assert source wording.
