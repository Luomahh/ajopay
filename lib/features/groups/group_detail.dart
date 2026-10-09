import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/errors/result.dart';
import '../../core/widgets/ajo_ui.dart';
import '../../domain/entities/group_details.dart';
import '../../domain/entities/savings_group.dart';
import '../auth/application/auth_providers.dart';
import 'group_providers.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailState();
}

class _GroupDetailState extends ConsumerState<GroupDetailScreen> {
  bool busy = false;
  bool checked = false;
  int? checkedVersion;
  String? error;

  Future<void> run(Future<Result<GroupDetails>> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await action();
    if (!mounted) return;
    result.when(
      success: (_) {
        checked = false;
        ref.invalidate(groupDetailsProvider(widget.groupId));
        ref.invalidate(groupsProvider);
      },
      failure: (failure) {
        error = failure.message;
      },
    );
    setState(() {
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(groupDetailsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Your savings circle'),
        actions: [
          IconButton(
            tooltip: 'Refresh group',
            onPressed: busy
                ? null
                : () => ref.invalidate(groupDetailsProvider(widget.groupId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            failure('Could not load this group. Please try again.'),
        data: (result) =>
            result.when(success: details, failure: (f) => failure(f.message)),
      ),
    );
  }

  Widget failure(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(groupDetailsProvider(widget.groupId)),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget details(GroupDetails d) {
    final g = d.group;
    final userId = ref.watch(sessionUserIdProvider);
    final owner = d.ownerId == userId;
    final me = d.member(userId);
    final draft = g.status == 'draft';
    final repo = ref.read(groupRepositoryProvider);
    final schedule = d.schedule;
    final today = DateTime.now().toUtc();
    final startPassed = g.firstPayoutDate.isBefore(
      DateTime.utc(today.year, today.month, today.day),
    );
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(groupDetailsProvider(widget.groupId));
        await ref.read(groupDetailsProvider(widget.groupId).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
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
                        draft
                            ? 'BUILDING YOUR CIRCLE'
                            : 'YOUR CIRCLE IS ACTIVE',
                        style: const TextStyle(
                          color: AjoColors.mint,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        g.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${d.members.length} of ${g.memberLimit} members · ${g.mode == SavingsMode.rotating ? 'Rotating ajo' : 'Save to a date'}',
                        style: const TextStyle(color: AjoColors.mint),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${formatNaira(g.contributionKobo)} / ${g.frequency.interval}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!draft) ...[
                  AjoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading(
                          owner ? 'Lead your circle' : 'Your contributions',
                        ),
                        Text(
                          owner
                              ? 'Review payment reports and confirm what has been received.'
                              : 'Record your payment any day within the contribution window and track the leader’s review.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              context.push('/groups/${g.id}/contributions'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            owner
                                ? 'Review group payments'
                                : 'Track my contributions',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (draft && g.inviteCode != null) ...[
                  AjoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading('Bring your people together'),
                        const Text(
                          'Share this code. Members can use Join a group on their home screen.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          g.inviteCode!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: g.inviteCode!),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invite code copied'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy invite code'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                AjoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading('Savings terms'),
                      Text(
                        'Each member contributes ${formatNaira(g.contributionKobo)} every ${g.frequency.interval}.',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'First contribution: ${dateOnly(g.firstPayoutDate)}',
                      ),
                      if (g.mode == SavingsMode.rotating)
                        Text(
                          'One member receives the ${formatNaira(g.contributionKobo * g.memberLimit)} pot each round, for ${g.memberLimit} rounds.',
                        ),
                      if (g.endDate != null)
                        Text('End date: ${dateOnly(g.endDate!)}'),
                      if (g.mode == SavingsMode.target)
                        Text(
                          'Planned principal per member: ${formatNaira(g.contributionKobo * schedule.length)} across ${schedule.length} contributions.',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scheduled dates are deadlines. Weekly contributions may be recorded on any of the seven days ending on that date, once the group is active.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Amounts assume all scheduled contributions are paid. No interest is included. AjoPay does not collect or transfer money yet.',
                        style: TextStyle(color: AjoColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AjoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading('Members · ${d.members.length}/${g.memberLimit}'),
                      for (final m in d.members)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AjoColors.mint,
                                child: Text(
                                  m.position?.toString() ?? '•',
                                  style: const TextStyle(
                                    color: AjoColors.forest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${m.name}${m.userId == userId ? ' (you)' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${m.role == 'owner' ? 'Leader · ' : ''}${m.acceptedVersion == d.version ? 'Terms confirmed' : 'Awaiting agreement'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AjoColors.muted,
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
                if (schedule.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  AjoPanel(
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        draft ? 'Review the schedule' : 'Agreed schedule',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${schedule.length} ${g.frequency.label.toLowerCase()} contributions',
                      ),
                      children: [
                        for (final p in schedule)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${p.number}. ${dateOnly(p.date)}'),
                            subtitle: p.recipientId == null
                                ? const Text('Every member contributes')
                                : Text(
                                    'Recipient: ${d.member(p.recipientId)?.name ?? 'Member'}',
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (draft)
                  AjoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading('Ready, together'),
                        Text(
                          '${d.agreedCount} of ${g.memberLimit} members have confirmed the terms.',
                        ),
                        if (!d.full)
                          const Text(
                            'Fill every member place before confirming terms.',
                          ),
                        if (d.full && !d.readyForAgreement) ...[
                          const Text(
                            'The leader must prepare the payout order. Everyone can review it before agreeing. The order can only be drawn once.',
                          ),
                          if (owner)
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() => repo.prepareOrder(g.id)),
                              child: const Text('Prepare payout order'),
                            ),
                        ],
                        if (d.readyForAgreement &&
                            me != null &&
                            me.acceptedVersion != d.version) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: checked && checkedVersion == d.version,
                            onChanged: busy
                                ? null
                                : (v) => setState(() {
                                    checked = v ?? false;
                                    checkedVersion = d.version;
                                  }),
                            title: const Text(
                              'I agree to these savings terms and the displayed schedule.',
                            ),
                          ),
                          FilledButton(
                            onPressed:
                                busy || !checked || checkedVersion != d.version
                                ? null
                                : () => run(
                                    () => repo.acceptTerms(g.id, d.version),
                                  ),
                            child: const Text('Confirm my agreement'),
                          ),
                        ],
                        if (startPassed)
                          const Text(
                            'The start date has passed. Create a new draft with a future date before starting.',
                          ),
                        if (owner) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: busy || !d.allAgreed || startPassed
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Activate this circle?',
                                        ),
                                        content: const Text(
                                          'Everyone has agreed. Activation locks membership and saves this schedule. It does not charge anyone or move money.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Not yet'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Activate'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && mounted) {
                                      await run(
                                        () => repo.activate(g.id, d.version),
                                      );
                                    }
                                  },
                            child: const Text('Activate group'),
                          ),
                        ] else
                          const Text(
                            'Your leader can activate the group once everyone agrees.',
                          ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const AjoPanel(
                    child: Text(
                      'Your group is active. Membership and the agreed schedule are locked. Record external payments in Contributions; AjoPay does not collect money.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AjoColors.forest,
      ),
    ),
  );
}
