import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ajo_ui.dart';
import '../../../../domain/entities/savings_group.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../groups/group_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AjoBrand(),
        ),
        actions: [
          IconButton(
            tooltip: 'Your profile',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final result = await ref.read(authRepositoryProvider).signOut();
              if (!context.mounted) return;
              result.when(
                success: (_) {},
                failure: (failure) => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(failure.message))),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupsProvider);
                await ref.read(groupsProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    'Make room for\nbigger plans.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Save for a goal, or take turns with your circle.',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AjoColors.forest,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.groups_rounded, color: AjoColors.mint),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'GROW TOGETHER',
                                style: TextStyle(
                                  color: AjoColors.mint,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'A little at a time.\nA lot more, together.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.2,
                            letterSpacing: -.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Choose a savings plan, set your pace,\nand grow together.',
                          style: TextStyle(
                            color: Color(0xFFCEE5D9),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AjoColors.mint,
                            foregroundColor: AjoColors.forest,
                          ),
                          onPressed: () => context.push('/groups/new'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create a group'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/groups/join'),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join a group'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your circles',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(groupsProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  groups.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const AjoPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finding your circles…',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8),
                          Text('This should only take a moment.'),
                          SizedBox(height: 18),
                          LinearProgressIndicator(minHeight: 3),
                        ],
                      ),
                    ),
                    error: (_, _) => _LoadError(
                      message: 'We couldn’t load your circles.',
                      retry: () => ref.invalidate(groupsProvider),
                    ),
                    data: (result) => result.when(
                      failure: (failure) => _LoadError(
                        message: failure.message,
                        retry: () => ref.invalidate(groupsProvider),
                      ),
                      success: (items) => items.isEmpty
                          ? const AjoPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 27,
                                    backgroundColor: AjoColors.mint,
                                    child: Icon(
                                      Icons.groups_2_outlined,
                                      color: AjoColors.forest,
                                      size: 29,
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  Text(
                                    'No groups yet',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: AjoColors.ink,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Every circle starts with one person. Create a draft above and decide what you’ll save together.',
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: items
                                  .map(
                                    (group) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _GroupCard(group: group),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: AjoColors.muted,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Your money stays with you. AjoPay tracks payments made outside the app.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AjoColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => AjoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AjoColors.muted, size: 30),
        const SizedBox(height: 12),
        const Text(
          'Let’s try that again',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AjoColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});
  final SavingsGroup group;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AjoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AjoColors.mint,
              child: Icon(
                Icons.people_outline_rounded,
                color: AjoColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          group.status == 'draft' ? 'Draft · round not started' : group.status,
        ),
        const SizedBox(height: 16),
        Text(
          formatNaira(group.contributionKobo),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${group.allowsExtra ? 'minimum ' : ''}per member, each ${group.frequency.interval}',
        ),
        Text(
          group.ownerId == ref.watch(sessionUserIdProvider)
              ? 'You lead this circle'
              : 'You are a member',
          style: const TextStyle(
            color: AjoColors.emerald,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: AjoColors.line),
        const SizedBox(height: 10),
        Text(
          '${group.memberLimit} planned members · ${group.mode == SavingsMode.rotating ? 'Rotating payouts' : 'Save to an end date'}',
        ),
        const SizedBox(height: 6),
        Text(
          group.mode == SavingsMode.rotating
              ? (group.rulesVersion >= 2
                    ? '${(group.payoutFrequency ?? group.frequency).label} payouts · accumulated contributions'
                    : 'Scheduled pot: ${formatNaira(group.contributionKobo * group.memberLimit)}')
              : 'End date: ${dateOnly(group.endDate!)}',
        ),
        const SizedBox(height: 6),
        Text(
          '${group.mode == SavingsMode.rotating ? 'First payout' : 'First contribution'}: ${dateOnly(group.firstPayoutDate)}',
        ),
        if (group.inviteCode != null && group.status == 'draft')
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: group.inviteCode!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invite code copied. Share it with your circle.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy invite code'),
          ),
        if (group.status == 'active')
          FilledButton.icon(
            onPressed: () => context.push('/groups/${group.id}/contributions'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(
              group.ownerId == ref.watch(sessionUserIdProvider)
                  ? 'Review group payments'
                  : 'Track my contributions',
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/groups/${group.id}'),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('View group'),
        ),
      ],
    ),
  );
}
