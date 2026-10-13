import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../../core/widgets/ajo_ui.dart';
import '../auth/application/auth_providers.dart';
import 'group_providers.dart';

final groupAccountProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) async {
      final user = ref.watch(sessionUserIdProvider);
      if (user == null) return null;
      return ref
          .watch(supabaseClientProvider)
          .from('group_bank_accounts')
          .select()
          .eq('group_id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
    });

class GroupAccountPanel extends ConsumerWidget {
  const GroupAccountPanel({
    super.key,
    required this.groupId,
    required this.canEdit,
  });
  final String groupId;
  final bool canEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AjoPanel(
    child: ref
        .watch(groupAccountProvider(groupId))
        .when(
          loading: () => const Text('Loading group bank details…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bank details could not load. Do not transfer until you have confirmed the destination.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(groupAccountProvider(groupId)),
                child: const Text('Retry bank details'),
              ),
            ],
          ),
          data: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Group payment account',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (row == null)
                const Text('Your leader has not added a bank account yet.')
              else ...[
                for (final field in [
                  ('Bank', 'bank_name'),
                  ('Account number', 'account_number'),
                  ('Account name', 'account_name'),
                ]) ...[
                  Text(field.$1, style: const TextStyle(fontSize: 12)),
                  SelectableText(
                    row[field.$2] as String,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: row['account_number'] as String),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account number copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy account number'),
                ),
                const Text(
                  'Added by the leader. AjoPay has not verified this account. Check the recipient name in your banking app before transferring.',
                ),
              ],
              if (canEdit)
                TextButton.icon(
                  onPressed: () async {
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          _AccountDialog(groupId: groupId, row: row),
                    );
                    if (saved == true) {
                      ref.invalidate(groupAccountProvider(groupId));
                      ref.invalidate(groupDetailsProvider(groupId));
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    row == null ? 'Add bank details' : 'Edit bank details',
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'This account receives savings contributions only. It is not an AjoPay-created virtual account. Bank details are locked when the group starts.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
  );
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({required this.groupId, this.row});
  final String groupId;
  final Map<String, dynamic>? row;
  @override
  ConsumerState<_AccountDialog> createState() => _AccountState();
}

class _AccountState extends ConsumerState<_AccountDialog> {
  final form = GlobalKey<FormState>();
  late final bank = TextEditingController(
        text: widget.row?['bank_name'] as String? ?? '',
      ),
      name = TextEditingController(
        text: widget.row?['account_name'] as String? ?? '',
      ),
      number = TextEditingController(
        text: widget.row?['account_number'] as String? ?? '',
      );
  bool busy = false;
  String? error;
  @override
  void dispose() {
    bank.dispose();
    name.dispose();
    number.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .rpc(
            'set_group_bank_account',
            params: {
              'p_group_id': widget.groupId,
              'p_bank_name': bank.text.trim(),
              'p_account_name': name.text.trim(),
              'p_account_number': number.text.trim(),
            },
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not save. Refresh the group and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Group bank details'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Use an account your group has agreed to pay into. Changing these details asks every member to agree to the terms again.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: bank,
                enabled: !busy,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Bank name'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter bank name' : null,
              ),
              TextFormField(
                controller: name,
                enabled: !busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter account name' : null,
              ),
              TextFormField(
                controller: number,
                enabled: !busy,
                maxLength: 10,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '10-digit account number',
                ),
                validator: (v) => RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Enter 10 digits',
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save bank details'),
        ),
      ],
    ),
  );
}
