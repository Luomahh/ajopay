import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/errors/result.dart';
import '../../core/widgets/ajo_ui.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/group_details.dart';
import '../../domain/entities/savings_group.dart';
import '../auth/application/auth_providers.dart';
import '../groups/group_providers.dart';
import 'contribution_providers.dart';
import 'payment_dialog.dart';
import 'receipt_viewer.dart';

class ContributionScreen extends ConsumerStatefulWidget {
  const ContributionScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends ConsumerState<ContributionScreen> {
  final reviewNote = TextEditingController();
  @override
  void dispose() {
    reviewNote.dispose();
    super.dispose();
  }

  int? selected;
  bool busy = false;
  String? error;
  void refresh() {
    ref.invalidate(contributionTrackerProvider(widget.groupId));
  }

  Future<bool> action(
    Future<Result<ContributionTracker>> Function() operation,
  ) async {
    if (busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await operation();
    if (!mounted) return false;
    final ok = result.when(
      success: (_) {
        refresh();
        return true;
      },
      failure: (f) {
        error = f.message;
        return false;
      },
    );
    setState(() {
      busy = false;
    });
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(groupDetailsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contributions'),
        leading: IconButton(
          tooltip: 'Group details',
          onPressed: () => context.go('/groups/${widget.groupId}'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Group chat',
            onPressed: () => context.push('/groups/${widget.groupId}/chat'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Refresh payments',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => problem('Could not load this group.', group: true),
        data: (r) => r.when(
          failure: (f) => problem(f.message, group: true),
          success: (d) {
            if (d.group.status == 'draft') {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your leader must activate the group before contributions can be recorded.',
                  ),
                ),
              );
            }
            return ref
                .watch(contributionTrackerProvider(widget.groupId))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => problem('Could not load contributions.'),
                  data: (r) => r.when(
                    success: (t) => content(d, t),
                    failure: (f) => problem(f.message),
                  ),
                );
          },
        ),
      ),
    );
  }

  Widget problem(String message, {bool group = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(
            onPressed: () {
              if (group) ref.invalidate(groupDetailsProvider(widget.groupId));
              refresh();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget content(GroupDetails d, ContributionTracker t) {
    final user = ref.watch(sessionUserIdProvider)!;
    final leader = d.ownerId == user;
    if (t.periods.isEmpty) {
      return problem('Your schedule is not available yet.');
    }
    final p = t.periods.firstWhere(
      (p) => p.number == (selected ?? t.defaultPeriod),
      orElse: () => t.periods.first,
    );
    final mine = t.payment(p.number, user);
    final expected = d.group.contributionKobo * d.members.length;
    final confirmed = t.confirmedKobo(p.number);
    final overdue = t.periods
        .where(
          (p) =>
              p.dueDate.isBefore(t.today) &&
              t.payment(p.number, user)?.status != 'confirmed',
        )
        .length;
    return RefreshIndicator(
      onRefresh: () async {
        refresh();
        await ref.read(contributionTrackerProvider(widget.groupId).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AjoPanel(
                    color: AjoColors.forest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leader
                              ? 'LEADER · PAYMENT REVIEW'
                              : 'MEMBER · MY SAVINGS',
                          style: const TextStyle(
                            color: AjoColors.mint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          d.group.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          d.group.status == 'completed'
                              ? 'This round is completed. View your contribution history below.'
                              : leader
                              ? 'See who has paid. Confirm money received.'
                              : 'Contribute at your pace, within each ${d.group.frequency.interval}.',
                          style: const TextStyle(color: AjoColors.mint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    initialValue: p.number,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Contribution period',
                    ),
                    items: [
                      for (final period in t.periods)
                        DropdownMenuItem(
                          value: period.number,
                          child: Text(
                            '${period.number} · Due ${dateOnly(period.dueDate)}',
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (n) => setState(() {
                            selected = n;
                            error = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  Text('Payment window: ${t.windowLabel(p)} · Nigeria time'),
                  const SizedBox(height: 8),
                  Text(
                    d.group.status == 'completed'
                        ? 'All scheduled payouts have been acknowledged. Contribution records are read-only.'
                        : d.group.frequency == SavingsFrequency.weekly
                        ? 'Pay on any day in this seven-day window. One full contribution covers this week.'
                        : 'Pay on any day in this window. One full contribution covers this period.',
                  ),
                  const Text(
                    'Transfer outside AjoPay using the details agreed with your group. Recording a payment does not move money.',
                    style: TextStyle(color: AjoColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  AjoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title('My contribution'),
                        Text(
                          formatNaira(d.group.contributionKobo),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          t.status(p, user),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AjoColors.emerald,
                          ),
                        ),
                        if (mine != null) ...[
                          Text('Paid on ${dateOnly(mine.paidOn)}'),
                          Text('Reference: ${mine.reference}'),
                          if (mine.paymentNote?.isNotEmpty == true)
                            Text('Your note: ${mine.paymentNote}'),
                          if (mine.receiptPath != null)
                            TextButton.icon(
                              onPressed: () =>
                                  showReceipt(context, ref, mine.receiptPath!),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('View screenshot'),
                            ),
                          if (mine.note != null)
                            Text('Leader’s note: ${mine.note}'),
                        ],
                        if (overdue > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '$overdue past period(s) are not yet confirmed. Use the period selector to check them.',
                            ),
                          ),
                        if (d.group.status == 'active' &&
                            p.isOpen(t.today) &&
                            (mine == null || mine.status == 'rejected')) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => submit(d, t, p, mine),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(
                              mine == null
                                  ? 'Record my payment'
                                  : 'Correct payment record',
                            ),
                          ),
                          if (p.dueDate.isBefore(t.today))
                            const Text(
                              'This is an overdue period. Recording it does not cover the current period.',
                            ),
                        ],
                        if (mine?.status == 'pending')
                          const Text(
                            'Your leader will check receipt. You cannot submit this period twice.',
                          ),
                        if (!p.isOpen(t.today))
                          Text('Recording opens on ${dateOnly(p.opensOn)}.'),
                      ],
                    ),
                  ),
                  if (leader) ...[
                    const SizedBox(height: 18),
                    AjoPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title('Group payment review'),
                          Text(
                            '${formatNaira(confirmed)} confirmed of ${formatNaira(expected)} expected',
                          ),
                          Text(
                            '${formatNaira(expected - confirmed)} still unconfirmed. Pending reports do not count as received.',
                          ),
                          const SizedBox(height: 10),
                          for (final m in d.members) reviewRow(d, t, p, m),
                        ],
                      ),
                    ),
                  ],
                  if (busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  AjoPanel(
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        leader ? 'Period activity' : 'My payment history',
                      ),
                      subtitle: const Text('Submissions and review decisions'),
                      children: [
                        if (!t.history.any((c) => c.period == p.number))
                          const Text(
                            'No payment activity for this period yet.',
                          ),
                        for (final h in t.history.where(
                          (c) => c.period == p.number,
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${leader ? '${d.member(h.userId)?.name ?? 'Member'} · ' : ''}${h.label}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attempt ${h.version} · ${formatNaira(h.amountKobo)}\nReference: ${h.reference}${h.note == null ? '' : '\n${h.note}'}',
                                ),
                                if (h.paymentNote?.isNotEmpty == true)
                                  Text('Member’s note: ${h.paymentNote}'),
                                if (h.receiptPath != null)
                                  TextButton.icon(
                                    onPressed: () => showReceipt(
                                      context,
                                      ref,
                                      h.receiptPath!,
                                    ),
                                    icon: const Icon(Icons.image_outlined),
                                    label: const Text(
                                      'View submitted screenshot',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
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

  Widget title(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AjoColors.forest,
      ),
    ),
  );

  Widget reviewRow(
    GroupDetails d,
    ContributionTracker t,
    ContributionPeriod p,
    GroupMember m,
  ) {
    final c = t.payment(p.number, m.userId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          Text(
            '${m.name}${m.userId == d.ownerId ? ' (leader)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(t.status(p, m.userId)),
          if (c != null) ...[
            Text('${formatNaira(c.amountKobo)} · ${dateOnly(c.paidOn)}'),
            SelectableText('Reference: ${c.reference}'),
            if (c.paymentNote?.isNotEmpty == true)
              Text('Member’s note: ${c.paymentNote}'),
            if (c.receiptPath != null)
              TextButton.icon(
                onPressed: () => showReceipt(context, ref, c.receiptPath!),
                icon: const Icon(Icons.image_outlined),
                label: const Text('View screenshot'),
              ),
            if (c.note != null) Text(c.note!),
          ],
          if (c?.status == 'pending')
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => review(d, c!, true),
                  child: const Text('Confirm receipt'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => review(d, c!, false),
                  child: const Text('Return for correction'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> submit(
    GroupDetails d,
    ContributionTracker t,
    ContributionPeriod p,
    Contribution? existing,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(
        groupId: d.group.id,
        amountKobo: d.group.contributionKobo,
        period: p,
        today: t.today,
        existing: existing,
      ),
    );
    if (saved == true && mounted) refresh();
  }

  Future<void> review(GroupDetails d, Contribution c, bool confirm) async {
    final note = reviewNote;
    note.clear();
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          confirm ? 'Confirm money received?' : 'Return this payment?',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  confirm
                      ? 'Confirm only after checking ${formatNaira(c.amountKobo)} was received. Reference: ${c.reference}. This is a manual record, not bank verification.'
                      : 'Explain what the member needs to correct. The amount will remain unconfirmed.',
                ),
                if (c.userId == d.ownerId && confirm)
                  const Text(
                    'This is your own contribution. Your confirmation will be recorded as the leader’s review.',
                  ),
                if (!confirm)
                  TextFormField(
                    controller: note,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Reason for correction',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Give a reason for the member.'
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(confirm ? 'Yes, received' : 'Send back'),
          ),
        ],
      ),
    );
    final text = note.text;
    if (accepted == true && mounted) {
      await action(
        () => ref
            .read(contributionRepositoryProvider)
            .review(
              groupId: d.group.id,
              period: c.period,
              userId: c.userId,
              version: c.version,
              confirm: confirm,
              note: text,
            ),
      );
    }
  }
}
