# Chat and contribution navigation

Contribution order: group payment account, contribution period, my contribution, late fees, PDF records and leader review/history. Account fields use consistent selectable typography. The contribution back button goes to the main dashboard. The dashboard circle card has one View group action; chat is in the group and contribution top bars. Chat returns to the previous screen when opened from it.

Messages use emerald outgoing bubbles, white incoming bubbles, date separators, a fixed composer and emoji picker. Native keyboard emoji also work. Message options are available through the three-dot menu:

- Delete for me hides a message from that account across devices. It remains visible to other members.
- Unsend for everyone is available only for the sender's own message. It replaces the stored body with a removal notice. People may already have read, copied or screenshotted it; this cannot retract such copies or prior database backups.

Supabase stores chat history independently of the device. There is no automatic expiry or cleanup job in AjoPay. Earlier messages load in pages of 50. This is not a promise of unlimited free storage or a backup service; provision storage and backups as the app grows. Chat is restricted to group members; it is not end-to-end encrypted. Active chat polls every five seconds and refreshes loaded history so removal notices update beyond page one.

Late-fee collection remains paused. No payment-provider integration, debit, penalty enforcement or payout restriction was added. Fee assessments remain separate from savings; members should not transfer them to the group's bank account.

Migration: `202610120002_chat_controls.sql`. Test suite: `supabase/tests/chat_controls.sql` checks sender-only removal, account-specific hiding, retry safety and access denial. Reconcile manually applied migration history before GitHub deployment.

Verified on 2026-10-12: 86 Flutter tests passed; contribution tests also reran after the final layout adjustment; static analysis clean; web build succeeded. All eight SQL suites passed locally. The chat-controls migration was applied to Supabase and its rollback-only authorization suite passed live. The emerald mobile chat was rendered and visually checked. No real user messages were removed during verification.
