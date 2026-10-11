# Payment screenshots and group chat

Implemented on 2026-10-10. The fifth migration is applied to the current Supabase project.

## Payment evidence

In an active group, select **Record my payment**. Enter the transfer reference and date, optionally select **Add payment screenshot**, and optionally write a **Note to leader**. Screenshots accept PNG, JPEG, or WebP up to 5 MB; notes accept up to 500 characters. The agreed amount remains fixed.

The leader opens **Review group payments**, refreshes, and selects **View screenshot**. The note appears alongside the report. Confirm only after matching the report against the receiving account. A screenshot is not independent verification that funds arrived.

Uploads and submissions keep the form intact after a failure. A completed upload is reused when retrying submission. Returned reports may be corrected; earlier notes and screenshot paths remain in history, accessible from **View submitted screenshot**.

The Storage bucket is private. A member can upload only under their own ID in an active group. Only that member and the group leader can read submitted evidence; peers and outsiders cannot. Leaders cannot read an uploaded image before it is submitted. Client update/delete is denied, preventing replacement of an existing screenshot. Views use a signed link valid for 60 seconds; anyone holding that temporary link can use it until expiry. Do not share the link.

Unsubmitted uploads may remain in storage after a cancelled or failed submission. An administrator cleanup/retention process is still needed; the app does not offer deletion of immutable evidence. Avoid including unrelated private information in a screenshot.

## Group chat

Select **Open group chat** in group details, or use the chat icon on the contribution screen. Members, including the leader, can send text messages in their own groups, including during draft setup. Messages show the sender, leader badge where applicable, and time.

Chat refreshes every five seconds while the app is in the foreground, with manual refresh and **Load earlier** for older messages. Messages are limited to 2,000 characters and 30 sends per minute per user/group. A failed send preserves the draft and its retry ID to avoid duplicate messages. Group membership is checked by the server on every request.

This version does not include push notifications, read receipts, edits, deletion, moderation, or chat attachments. Payment screenshots stay in the private payment-review flow rather than group chat.

## Verification

`supabase/tests/receipts_and_chat.sql` passed in the live SQL Editor using synthetic accounts, followed by rollback. It verifies bucket settings, upload paths, leader/uploader/peer/outsider access, immutable evidence, optional notes, submission retries, correction history, chat membership, sender labels, duplicate prevention, and cursor pagination. It tests Storage metadata policies; it does not upload actual image bytes through the Storage API.

Flutter regression tests exercise optional evidence, failed-upload recovery, chat retries, incoming refresh, and keyboard layout. A two-account device acceptance check remains necessary:

1. Use a clearly labelled demo group with an open contribution window.
2. As member, attach a non-sensitive sample screenshot and optional note; submit once.
3. As leader, refresh, open the image, read the note, and return the demo report for correction.
4. As member, correct it and resubmit; verify the earlier evidence remains in history.
5. Send a demo message from each account and check the other account receives it while chat is open.
