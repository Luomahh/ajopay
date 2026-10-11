# AjoPay

A Flutter app for coordinating rotating savings groups (ajo/esusu).

## Current state

Authentication, draft creation, invite-code joining, member agreement, activation, and agreed schedules are implemented. Groups support daily, weekly, or monthly contributions and either rotating payouts or saving to an end date.

Active groups now have separate member contribution tracking and leader payment review. Members record external transfers with a reference, payment date, optional screenshot, and optional note. Leaders confirm receipt or return reports with a reason. Weekly payments can be recorded during the seven days ending on the scheduled deadline. One full contribution covers each period; overdue periods remain visible. Confirmed totals exclude pending and returned reports.

All six group/contribution/chat/payout migrations are applied to the matching Supabase project. Live rollback-only SQL suites have verified group lifecycle and contribution authorization. See [group setup](docs/GROUPS_SETUP.md), [contribution tracking](docs/CONTRIBUTIONS.md), and the [delivery plan](docs/DELIVERY_PLAN.md). Payout recording, recipient acknowledgement, problem reports, correction history, and automatic round completion are implemented for both savings modes. See [payout tracking](docs/PAYOUTS.md). Android debug/release builds and emulator startup are verified. The developer confirmed the two-account payout flow. Physical-device and offline/restart checks remain; use the [demo and acceptance guide](docs/DEMO_GUIDE.md).

Each group also has member-only text chat with automatic refresh. Receipts are private to the submitting member and group leader. See [receipts and chat](docs/RECEIPTS_AND_CHAT.md) for usage and verification.

## Demo previews

Fictional-data screenshots and a three-minute walkthrough are in the [demo guide](docs/DEMO_GUIDE.md). A [portfolio summary and draft CV bullets](docs/PORTFOLIO_CASE_STUDY.md) document the implemented project and its limits.

## Stack

Flutter and Dart, Riverpod for state management, GoRouter for navigation, and Supabase Auth/Postgres for authentication and server-enforced group rules. Amounts are stored as integer kobo.

## Supabase backend

The backend source lives in this same repository under [`supabase/`](supabase/README.md): schema migrations, membership permissions, group activation, contribution recording/review functions, and rollback-only SQL regression tests.

This repository contains backend source code, not live user/payment records or a database backup. The existing profile table and signup trigger are prerequisites documented in the backend setup guide. Do not rerun migrations against the already-configured project.

## Local setup

1. Use Flutter with Dart 3.12.2 or compatible newer Dart 3.x. This checkout was checked with Flutter 3.44.6.
2. Run `flutter pub get`.
3. If `.env` does not exist, copy `.env.example` to `.env` and set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to your project's URL and public client key.
4. Run `flutter run -d chrome`, or select your Android emulator with `flutter devices` and run `flutter run -d <device-id>`.

The `.env` asset ships with the app: it must contain public client configuration only. Never add a Supabase service-role or secret key. Configure Supabase email confirmation and redirect URLs for your development target. When confirmation is enabled, follow the email link before signing in.

## Checks

```sh
flutter analyze
flutter test
flutter build web
```

Flutter tests use fake repositories and HTTP fixtures. SQL tests separately verify the live database rules using temporary, rolled-back users; a two-account device walkthrough remains a manual acceptance check. iOS requires a complete Xcode installation and CocoaPods. Android tooling availability alone does not verify an Android build.

## Structure

- `lib/features/auth`: forms, controllers, and authentication providers.
- `lib/domain/repositories`: backend-independent authentication, group, and contribution contracts.
- `lib/data/repositories`: Supabase implementation.
- `lib/app/router.dart`: authentication redirects with a stable router lifecycle.
- `lib/features/contributions`: member recording, leader review, and period history.
- `lib/features/payouts`: leader transfer records, recipient acknowledgement, disputes, and completed rounds.
- `test`: authentication, group, contribution UI, domain, and repository tests.
- `supabase`: versioned schema migrations and rollback-only authorization tests.

This is an early portfolio project. It does not currently collect, hold, or transfer money.

### New group rules and web preview

New drafts support separate contribution/payout schedules, minimum-plus-extra target savings, leader-supplied bank details, member profiles and a separate late-fee assessment. Existing groups retain their agreed terms. The web app has a responsive landing page and the app has a new AjoPay mark. See [rules and limitations](docs/FLEXIBLE_SAVINGS.md) and [web preview instructions](docs/WEB_PREVIEW.md). Identity verification, automatic account creation, in-app money movement and fee collection are not live.
