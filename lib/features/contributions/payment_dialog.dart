import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/receipt_image.dart';
import '../../domain/entities/savings_group.dart';
import 'contribution_providers.dart';
import 'receipt_service.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({
    super.key,
    required this.groupId,
    required this.amountKobo,
    required this.period,
    required this.today,
    this.existing,
    this.allowExtra = false,
    this.lateFeeKobo = 0,
  });
  final String groupId;
  final int amountKobo;
  final bool allowExtra;
  final int lateFeeKobo;
  final ContributionPeriod period;
  final DateTime today;
  final Contribution? existing;
  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(
    text: ((widget.existing?.amountKobo ?? widget.amountKobo) / 100)
        .toStringAsFixed(2),
  );
  late final reference = TextEditingController(
    text: widget.existing?.reference ?? '',
  );
  late final note = TextEditingController(
    text: widget.existing?.paymentNote ?? '',
  );
  late DateTime paidOn = widget.existing?.paidOn ?? widget.today;
  late String? path = widget.existing?.receiptPath;
  ReceiptImage? image;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    setState(() => busy = true);
    final result = await ref.read(receiptServiceProvider).pick();
    if (!mounted) return;
    result.when(
      success: (picked) {
        if (picked != null) {
          image = picked;
          path = null;
          error = null;
        }
      },
      failure: (f) => error = f.message,
    );
    setState(() => busy = false);
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    if (image != null && path == null) {
      final result = await ref
          .read(receiptServiceProvider)
          .upload(widget.groupId, image!);
      if (!mounted) return;
      if (result is Error<String>) {
        setState(() {
          error = result.failure.message;
          busy = false;
        });
        return;
      }
      path = (result as Success<String>).value;
    }
    final result = await ref
        .read(contributionRepositoryProvider)
        .submit(
          groupId: widget.groupId,
          period: widget.period.number,
          amountKobo: widget.allowExtra
              ? parseNairaToKobo(amount.text)!
              : widget.amountKobo,
          reference: reference.text,
          paidOn: paidOn,
          expectedVersion: widget.existing?.version ?? 0,
          receiptPath: path,
          paymentNote: note.text,
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
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Record an external payment'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${formatNaira(widget.amountKobo)} for period ${widget.period.number}. Only record money you have already sent.',
              ),
              if (widget.allowExtra)
                TextFormField(
                  controller: amount,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount paid (NGN)',
                    helperText:
                        'Minimum ${formatNaira(widget.amountKobo)}. Extra savings are yours.',
                  ),
                  validator: (v) {
                    final n = parseNairaToKobo(v ?? '');
                    return n == null || n < widget.amountKobo || n > 100000000
                        ? 'Enter at least ${formatNaira(widget.amountKobo)}, up to NGN 1,000,000.'
                        : null;
                  },
                ),
              if (widget.lateFeeKobo > 0 &&
                  paidOn.isAfter(widget.period.dueDate))
                Text(
                  'Late fee: ${formatNaira(widget.lateFeeKobo)}, separate from savings. Fee collection is not available yet. Do not include it in the contribution amount.',
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reference,
                enabled: !busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Transfer reference',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Enter the reference from your transfer receipt.'
                    : null,
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final chosen = await showDatePicker(
                          context: context,
                          initialDate: paidOn,
                          firstDate: widget.period.opensOn,
                          lastDate: widget.today,
                        );
                        if (chosen != null && mounted) {
                          setState(() => paidOn = chosen);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Paid on ${dateOnly(paidOn)}'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : choose,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  image != null || path != null
                      ? 'Change screenshot'
                      : 'Add payment screenshot',
                ),
              ),
              const Text(
                'Optional · PNG, JPG or WebP · up to 5 MB',
                style: TextStyle(fontSize: 12),
              ),
              if (image != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Image.memory(
                    image!.bytes,
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      'Image preview unavailable. Choose another screenshot.',
                    ),
                  ),
                ),
              if (path != null && image == null)
                const Text('Previous screenshot attached'),
              if (path != null || image != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          path = null;
                          image = null;
                        }),
                  child: const Text('Remove screenshot'),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                enabled: !busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note to leader (optional)',
                  hintText:
                      'Anything your leader should know about this payment?',
                ),
              ),
              const Text(
                'Only you and your leader can view this receipt and note. A screenshot is supporting evidence, not bank verification.',
                style: TextStyle(fontSize: 12),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : send,
          child: Text(busy ? 'Saving…' : 'Submit for review'),
        ),
      ],
    ),
  );
}
