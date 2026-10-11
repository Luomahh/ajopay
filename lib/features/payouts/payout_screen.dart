import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/widgets/ajo_ui.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/savings_group.dart';
import '../auth/application/auth_providers.dart';
import '../groups/group_providers.dart';
import 'payout_providers.dart';
import 'payout_dialog.dart';

class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  void refresh() => ref.invalidate(payoutTrackerProvider(widget.groupId));
  Future<void> act(PayoutTracker t, Payout p, {bool? received}) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayoutDialog(
        groupId: widget.groupId,
        payout: p,
        today: t.today,
        received: received,
        selfReview: received != null && p.recipientId == t.ownerId,
      ),
    );
    if (done == true && mounted) {
      refresh();
      ref.invalidate(groupDetailsProvider(widget.groupId));
      ref.invalidate(groupsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = ref.watch(payoutTrackerProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payouts'),
        leading: IconButton(
          tooltip: 'Group details',
          onPressed: () => context.go('/groups/${widget.groupId}'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh payouts',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: tracker.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => problem('Could not load payouts.'),
        data: (r) =>
            r.when(success: content, failure: (f) => problem(f.message)),
      ),
    );
  }

  Widget problem(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: refresh, child: const Text('Try again')),
        ],
      ),
    ),
  );
  Widget content(PayoutTracker t) {
    final user = ref.watch(sessionUserIdProvider);
    final leader = user == t.ownerId;
    final completed = t.groupStatus == 'completed';
    return RefreshIndicator(
      onRefresh: () async {
        refresh();
        await ref.read(payoutTrackerProvider(widget.groupId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AjoPanel(
                    color: AjoColors.forest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed
                              ? 'SAVINGS ROUND COMPLETED'
                              : 'THE NEXT STEP FOR YOUR SAVINGS',
                          style: const TextStyle(
                            color: AjoColors.mint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.groupName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${t.confirmedCount} of ${t.payouts.length} payouts acknowledged',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatNaira(t.confirmedKobo)} confirmed received by recipients',
                          style: const TextStyle(color: AjoColors.mint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    completed
                        ? 'Every scheduled recipient has confirmed receipt. Your group history remains available.'
                        : t.mode == 'target'
                        ? 'At the agreed end date, each member receives their saved principal. All scheduled contributions must be confirmed first. No interest is included.'
                        : 'Payouts follow the agreed order and dates. Each pot needs all contributions confirmed, and the previous recipient must acknowledge receipt.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transfers happen outside AjoPay. These are member and leader records, not bank-verified balances.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/groups/${widget.groupId}/contributions'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View contributions'),
                  ),
                  const SizedBox(height: 16),
                  if (t.payouts.isEmpty)
                    const AjoPanel(
                      child: Text(
                        'Activate the group to see its agreed payout schedule.',
                      ),
                    ),
                  for (final p in t.payouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AjoPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              p.slot == 0
                                  ? 'End-date savings payout'
                                  : 'Period ${p.slot}',
                              style: const TextStyle(
                                color: AjoColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${p.recipientName}${p.recipientId == user ? ' · You' : ''}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AjoColors.forest,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatNaira(p.amountKobo),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AjoColors.emerald,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Scheduled: ${dateOnly(p.dueOn)}'),
                            const SizedBox(height: 8),
                            Text(
                              p.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (p.version == 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Confirmed contributions: ${formatNaira(p.confirmedPoolKobo)} / ${formatNaira(p.expectedPoolKobo)}',
                              ),
                              if (p.shortfallKobo > 0)
                                Text(
                                  'Still to confirm: ${formatNaira(p.shortfallKobo)}',
                                ),
                            ],
                            if (p.reference != null) ...[
                              const SizedBox(height: 12),
                              Text('Transfer reference: ${p.reference}'),
                              Text(
                                'Sent: ${dateOnly(p.paidOn!)} · Record version ${p.version}',
                              ),
                            ],
                            if (p.leaderNote?.isNotEmpty == true)
                              Text('Leader’s note: ${p.leaderNote}'),
                            if (p.recipientNote?.isNotEmpty == true)
                              Text('Recipient’s note: ${p.recipientNote}'),
                            if (leader && p.canRecord && !completed) ...[
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => act(t, p),
                                icon: const Icon(Icons.edit_note_rounded),
                                label: Text(
                                  p.version == 0
                                      ? 'Record payout'
                                      : 'Correct payout record',
                                ),
                              ),
                              if (p.version > 0)
                                const Text(
                                  'Check the existing transfer first. A correction does not mean you should send the money again.',
                                ),
                            ],
                            if (p.recipientId == user &&
                                p.awaitingRecipient &&
                                !completed) ...[
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: () => act(t, p, received: true),
                                child: const Text('I received this money'),
                              ),
                              if (p.status == 'reported')
                                TextButton(
                                  onPressed: () => act(t, p, received: false),
                                  child: const Text('Report a problem'),
                                ),
                            ],
                            if (t.history.any(
                              (h) =>
                                  h.slot == p.slot &&
                                  h.recipientId == p.recipientId,
                            ))
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Payout history'),
                                children: [
                                  for (final h in t.history.where(
                                    (h) =>
                                        h.slot == p.slot &&
                                        h.recipientId == p.recipientId,
                                  ))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${payoutStatusLabel(h.status)} · Version ${h.version}',
                                      ),
                                      subtitle: Text(
                                        '${dateOnly(h.createdAt.toLocal())} · ${formatNaira(h.amountKobo)}\nReference: ${h.reference}\nSent: ${dateOnly(h.paidOn)}${h.leaderNote == null ? '' : '\nLeader: ${h.leaderNote}'}${h.recipientNote == null ? '' : '\nRecipient: ${h.recipientNote}'}',
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
