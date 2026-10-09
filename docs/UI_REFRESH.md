# AjoPay interface refresh

The implemented screens now share an emerald, mint, and off-white design system: sign-in, sign-up, dashboard, and group creation. Theme tokens live in lib/app/theme.dart; reusable brand, panel, and authentication layouts live in lib/core/widgets/ajo_ui.dart.

The visual direction uses original copy and layouts. General fintech UX references reviewed: https://inside.cowrywise.com/article/how-dynamic-piils-personalize-wealth-building and https://dashboard.piggyvest.com/login . No competitor assets were copied.

## Reliability
- Authentication transport errors no longer count as an explicit signed-out event. Routing and group fetching use the resolved session identity. Actual signed-out events still redirect to sign-in; backend authorization remains authoritative.
- Same-user authentication refreshes no longer unnecessarily refetch groups.
- Group requests have a 15-second timeout. An uncertain create response can still finish server-side; retries retain the form request ID for idempotency.
- Dashboard loading, empty, and failed states are distinct. Failures offer retry, and pull-to-refresh is supported.

## Verification
Regression coverage includes amount entry while the keyboard changes size and auth emits a transport error, subsequent same-user refresh, explicit sign-out, retry with preserved draft/request ID, and stalled repository requests. Mobile and desktop screenshots were rendered using fake data; no live accounts or groups were created for preview.

A real-device confirmation is still needed for the originally reported bounce, because it may also involve a genuinely expired server session. Join/detail screens remain unimplemented placeholders and were not exposed as dummy navigation.
