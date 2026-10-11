import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/savings_group.dart';
import 'payout_providers.dart';

/// A null decision records a transfer; true/false acknowledges receipt/a problem.
class PayoutDialog extends ConsumerStatefulWidget {
  const PayoutDialog({
    super.key,
    required this.groupId,
    required this.payout,
    required this.today,
    this.received,
    this.selfReview = false,
  });
  final String groupId;
  final Payout payout;
  final DateTime today;
  final bool? received;
  final bool selfReview;
  @override
  ConsumerState<PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends ConsumerState<PayoutDialog> {
  final form = GlobalKey<FormState>();
  late final reference = TextEditingController(
    text: widget.payout.reference ?? '',
  );
  late final note = TextEditingController(
    text: widget.received == null ? widget.payout.leaderNote ?? '' : '',
  );
  late DateTime paidOn = widget.payout.paidOn ?? widget.today;
  bool busy = false, checked = false;
  String? error;
  @override
  void dispose() {
    reference.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !checked || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final repo = ref.read(payoutRepositoryProvider);
    final p = widget.payout;
    final result = widget.received == null
        ? await repo.record(
            groupId: widget.groupId,
            slot: p.slot,
            recipientId: p.recipientId,
            amountKobo: p.amountKobo,
            reference: reference.text,
            paidOn: paidOn,
            expectedVersion: p.version,
            note: note.text,
          )
        : await repo.acknowledge(
            groupId: widget.groupId,
            slot: p.slot,
            version: p.version,
            received: widget.received!,
            note: note.text,
          );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        error = f.message;
        busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.received == null;
    final confirming = widget.received == true;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          recording
              ? (widget.payout.version > 0
                    ? 'Correct payout record'
                    : 'Record external payout')
              : confirming
              ? 'Confirm money received'
              : 'Report a payout problem',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${formatNaira(widget.payout.amountKobo)} → ${widget.payout.recipientName}',
                ),
                const SizedBox(height: 12),
                Text(
                  recording
                      ? 'Record a transfer you already made outside AjoPay. Retrying this form does not send money.'
                      : confirming
                      ? 'Check your receiving account before confirming. This acknowledgement is final.'
                      : 'Explain what is missing or incorrect so your leader can investigate.',
                ),
                if (widget.selfReview)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'You are both the leader and recipient. This will be recorded as your own acknowledgement, without independent verification.',
                    ),
                  ),
                const SizedBox(height: 16),
                if (recording) ...[
                  TextFormField(
                    controller: reference,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Payout transfer reference',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Enter the reference from the transfer.'
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: paidOn,
                              firstDate: widget.payout.dueOn,
                              lastDate: widget.today,
                            );
                            if (value != null && mounted) {
                              setState(() => paidOn = value);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Sent on ${dateOnly(paidOn)}'),
                  ),
                ] else if (widget.payout.reference != null)
                  Text('Reference: ${widget.payout.reference}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  enabled: !busy,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: widget.received == false
                        ? 'What went wrong?'
                        : 'Note (optional)',
                  ),
                  validator: (v) =>
                      widget.received == false && (v?.trim().length ?? 0) < 3
                      ? 'Please describe the problem.'
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checked,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => checked = v ?? false),
                  title: Text(
                    recording
                        ? 'I have already sent this full amount to this recipient.'
                        : confirming
                        ? 'I have received the full amount in my account.'
                        : 'I have checked the transfer details and want the leader to investigate.',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
            onPressed: busy || !checked ? null : submit,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    recording
                        ? 'Save payout record'
                        : confirming
                        ? 'Confirm receipt'
                        : 'Send problem report',
                  ),
          ),
        ],
      ),
    );
  }
}
