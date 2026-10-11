# Web feedback preview

The Flutter web app now opens a public emerald landing page at `/`; sign-in and signup lead to the existing authenticated app. Mobile startup remains sign-in. The landing page uses stacked layouts on small screens and side-by-side sections on wide screens. Forms and trackers use bounded, scrollable layouts. The web manifest permits either orientation.

The new code-native AjoPay mark replaces the infinity symbol and Flutter launcher assets on web, Android and iOS. Regenerate matching icons with `flutter test tool/generate_brand_assets.dart`.

To check locally:

```sh
flutter test
flutter analyze
flutter build web
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8765`. This local URL is not shareable with remote testers. No public hosting deployment has been made.

For a hosted feedback preview, deploy **only `build/web`** to an HTTPS static host. Keep hash routing enabled (the current default), which avoids deep-link rewrite requirements. Configure Supabase Authentication Site URL and allowed confirmation/redirect URLs for that exact preview domain, then test signup confirmation and sign-in on the hosted origin before inviting testers. Use a separate preview Supabase project for disposable test data if real members start using production.

Only the Supabase project URL and public/anon client key belong in the Flutter environment asset. A browser can read bundled assets; never add service-role, provider, database or identity-verification secrets. `.env` is ignored by Git and must be supplied separately in a hosted build.

Feedback script: create a new weekly/monthly rotating draft, add bank details, join with a second account, check both schedules and profiles, agree and activate. Separately test end-date savings with an amount above the minimum and below it. Check the payment evidence/review flow and late-fee display. Do not send real money to demonstration accounts.

Layouts checked at 320, 768 and 1440 logical pixels, including enlarged text for the landing page. Browser/OS coverage is not a claim that every physical device has been tested.
