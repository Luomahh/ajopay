# Notifications and reminder setup

## Available in the app

The dashboard bell shows an unread badge and opens recent notifications. Notifications are private to their recipient and require current group membership. Opening a notification marks it read. Reaching the bottom of a chat marks only messages through the loaded sequence as read; new messages remain unread. The bell refreshes every 30 seconds while the dashboard is mounted. This is an in-app inbox, not device push notifications.

Payment events say **Payment reported** while awaiting leader review and **Payment confirmed by leader** once reviewed. Neither is a bank settlement receipt. A leader also receives a review alert when a member reports a payment. Group message alerts identify the sender and circle without copying the message body into notifications or external messages.

Reminder dates use Africa/Lagos:
- Daily contributions: due date.
- Weekly: six days before, three days before, and the due date (three reminders during the window).
- Monthly: weekly from the window opening, plus the due date.
- Overdue: the day after the deadline, then weekly.

There is at most one generated reminder per group/member per day. When several periods are outstanding, today's deadline takes priority, then the most recent eligible period. Pending and confirmed reports suppress reminders for that period. Retried jobs cannot duplicate the same notification. Reporting a payment cancels queued reminder deliveries for the period. Opting out cancels queued items for that channel.

## Email and SMS are NOT sending yet

No delivery provider is configured. Profile → Email & SMS reminders records explicit opt-in, off by default. `notification_outbox` queues opted-in reminders and payment updates; it does not send anything. Chat alerts currently stay in-app. No marketing messages or messages to real users were sent during development.

The app's Supabase authentication email configuration is separate from sending payment reminders. Never put provider credentials or the Supabase service-role key in Flutter assets, Git, screenshots or chat.

## Background preparation

Migration `202610130001_notifications_and_replies.sql` installs `prepare_scheduled_reminders()`, callable only by the service role/admin. Opening the notification feed also prepares that member's reminders for the current Nigeria date.

On hosted Supabase, enable pg_cron and schedule this preparation at 07:00 UTC / 08:00 Nigeria time:

```sql
select cron.schedule(
 'ajopay-reminder-preparation',
 '0 7 * * *',
 'select public.prepare_scheduled_reminders();'
);
```

Do not add duplicate job names. Check `cron.job` and `cron.job_run_details` after installation. Preparation alone sends no external messages.

## Connecting delivery later

1. Choose an email service and verify a sending domain you control. For example, Resend requires DNS domain verification. Use a transactional address such as reminders@your-domain and configure SPF/DKIM with the provider. A sample domain must not be used in production.
2. Choose an SMS provider that supports Nigerian destinations and complete its sender/account requirements. SMS is a paid delivery channel; configure a spending cap and test destination first. Verify phone ownership before enabling live SMS; profile phone numbers are currently self-reported.
3. Store provider credentials as Supabase Edge Function secrets. Use the member's confirmed account email/private profile phone, never a contact passed by the client.
4. Implement and deploy the provider-specific sending worker. It must accept only a scheduler secret/service identity, claim queued rows atomically, recheck opt-in and membership immediately before sending, suppress reminders when a payment is pending/confirmed, and expire stale queued events rather than delivering a backlog at launch. Do not replay the current queue blindly when enabling sending.
5. Use each outbox ID as a provider idempotency key; handle uncertain timeouts without sending duplicate SMS, record provider message IDs, and process signed delivery/bounce/opt-out webhooks. Marking `sent` means provider acceptance, not confirmed delivery. Add an unsubscribe mechanism and honor provider STOP requests before broad rollout.
6. Schedule the worker through Supabase Cron/Edge Functions only after sandbox tests pass. Test email and SMS separately with owned test contacts, confirm recipient/content, then enable live sending. Budget limits, rate limits and retry handling must be configured before rollout.

The provider-specific delivery worker and live credentials are still pending; the queue and schedules are the prepared foundation. No fake success state is shown for external delivery.

Official references:
- https://supabase.com/docs/guides/functions/schedule-functions
- https://supabase.com/docs/guides/functions/secrets
- https://resend.com/docs/dashboard/domains/introduction

## Verification — 2026-10-13

89 Flutter tests passed and static analysis was clean. All nine SQL regression suites passed locally; the new notifications/replies suite also passed against hosted Supabase with rollback-only fixtures. Migration `202610130001` was applied live. The hosted `ajopay-reminder-preparation` cron job is active at 07:00 UTC (08:00 Nigeria time), preparing notifications only. Its first scheduled execution has not yet been observed. No external delivery worker is installed. Reconcile manually applied migration history before GitHub deployment.
