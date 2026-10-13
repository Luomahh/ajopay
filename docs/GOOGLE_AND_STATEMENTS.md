# Account and statement update

Email signup collects full name, email, password and phone. Nigerian local mobile numbers normalize to +234; international numbers use +countrycode. Phone numbers are self-reported and are not proof of identity. Existing and Google users missing contact details complete their profile before entering the app. This is an onboarding UI check, not a verified-identity authorization boundary.

Phone sharing is off by default. Owners can opt in to sharing with fellow group members. Names, city and bio remain group-visible; addresses are owner-only through profile RLS. BVN/NIN are not collected or displayed. Only admins with privileged database access can bypass RLS; owner-only here describes app-user access.

Migration: `supabase/migrations/202610120001_contact_and_statements.sql`. Apply after all existing migrations. Do not replay manually applied migrations through GitHub integration without reconciling Supabase migration history first.

Active and completed groups have a Download payment records (PDF) action. Choose dates, prepare, then save/share or print. Leaders export all group records; members export their own contributions and payouts. Server-side membership checks enforce the scope. Maximum date span is 366 days, maximum 5000 records; choose a shorter range if needed. Reports contain latest payment statuses rather than audit revisions, Nigeria recording times, dates, amounts and references. Confirmed contributions and acknowledged payouts have separate totals. Assessed late fees remain separate and are not collected. Reports exclude phone numbers, addresses, identity numbers, screenshots and private notes.

## Google setup still required

Google authentication is implemented but **disabled by default** until the provider is configured and tested. Email signup/sign-in continues to work. No client secret belongs in the Flutter app, Git, environment assets or chat.

1. In Google Cloud, create/select the AjoPay project. Configure Google Auth Platform branding, support email and audience. Use the minimal OpenID/email/profile scopes. Add test users while the consent screen is in Testing. Public release may require Google branding/domain verification.
2. Create an OAuth client of type **Web application** for Supabase's hosted OAuth flow. Set authorized JavaScript origins to the exact hosted HTTPS app origin (and localhost development origin if used).
3. Add this authorized redirect URI exactly: `https://zseyvvpsccexxddnnhwr.supabase.co/auth/v1/callback`.
4. In AjoPay Supabase Authentication → Sign In / Providers → Google, enable Google and enter the client ID and client secret there. Save them in Supabase only.
5. In Authentication URL Configuration, set the correct web Site URL and allow the exact web return URL plus `com.luomah.ajopay://login-callback/` for Android/iOS. Local testing uses `http://127.0.0.1:8765/` if that is the preview origin. Use a fixed port when running Flutter web directly and allow that exact origin too.
6. Run/build with `--dart-define=GOOGLE_SIGN_IN_ENABLED=true`. Until then the Google button explains that email is available.
7. Test a fresh Google user, existing email user, cancel, signout, web reload, and Android/iOS callback. Google does not provide the required phone here, so a new Google user must complete contact details. Do not call this live-ready before real provider tests pass.

Official setup: https://supabase.com/docs/guides/auth/social-login/auth-google
Mobile redirect guidance: https://supabase.com/docs/guides/auth/native-mobile-deep-linking

## Payments

No provider is connected. Group bank details and transfer evidence remain the payment flow. Paystack Starter onboarding is available to some unregistered businesses, but does not provide transfers or identity verification; dedicated virtual accounts require registered, approved businesses. Provider approval for this savings use case must be confirmed. Payment collection is not free and no live provider credentials have been supplied.

Sources checked: https://support.paystack.com/en/articles/2128898 and https://paystack.com/docs/payments/dedicated-virtual-accounts/

Validation on 2026-10-12: 85 Flutter tests pass; analysis clean; web build succeeds; all seven SQL suites pass locally and on Supabase after applying the migration. A four-page synthetic PDF was rendered and all pages visually reviewed. Native print/share UI and real Google callbacks have not been tested on physical devices.
