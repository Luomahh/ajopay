import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../../domain/entities/savings_group.dart';
import '../auth/application/auth_providers.dart';
import 'statement_pdf.dart';

class StatementButton extends StatelessWidget {
  const StatementButton({super.key, required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _StatementDialog(groupId: groupId),
    ),
    icon: const Icon(Icons.download_outlined),
    label: const Text('Download payment records (PDF)'),
  );
}

class _StatementDialog extends ConsumerStatefulWidget {
  const _StatementDialog({required this.groupId});
  final String groupId;
  @override
  ConsumerState<_StatementDialog> createState() => _StatementState();
}

class _StatementState extends ConsumerState<_StatementDialog> {
  late DateTimeRange range;
  Uint8List? bytes;
  bool busy = false;
  String? error;
  String? exportUser;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 1));
    final today = DateTime(now.year, now.month, now.day);
    range = DateTimeRange(
      start: today.subtract(const Duration(days: 90)),
      end: today,
    );
  }

  String get filename =>
      'ajopay-${widget.groupId}-${dateOnly(range.start)}-${dateOnly(range.end)}.pdf';
  Future<void> generate() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      bytes = null;
    });
    final user = ref.read(sessionUserIdProvider);
    try {
      final data = await ref
          .read(supabaseClientProvider)
          .rpc(
            'get_group_statement',
            params: {
              'p_group_id': widget.groupId,
              'p_from': dateOnly(range.start),
              'p_to': dateOnly(range.end),
            },
          )
          .timeout(const Duration(seconds: 30));
      final fonts = await Future.wait([
        rootBundle.load('assets/fonts/Lato-Regular.ttf'),
        rootBundle.load('assets/fonts/Lato-Bold.ttf'),
      ]);
      final generated = await buildStatementPdf(
        Map<String, dynamic>.from(data as Map),
        regularFont: fonts[0],
        boldFont: fonts[1],
      );
      if (!mounted) return;
      if (user == null || ref.read(sessionUserIdProvider) != user) {
        throw StateError('Session changed');
      }
      bytes = generated;
      exportUser = user;
    } catch (_) {
      error =
          'Could not prepare records. Try a shorter date range or check your connection.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> export(bool print) async {
    if (bytes == null || busy) return;
    if (exportUser != ref.read(sessionUserIdProvider)) {
      setState(() {
        bytes = null;
        error = 'Your session changed. Prepare the records again.';
      });
      return;
    }
    setState(() => busy = true);
    try {
      if (print) {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) => Future.value(bytes!),
        );
      } else {
        await Printing.sharePdf(bytes: bytes!, filename: filename);
      }
    } catch (_) {
      error = 'Could not open the download or print service. Please try again.';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Payment records'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Leaders receive the group’s records. Members receive only their own contributions and payouts. Keep downloaded copies private.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(now.year, now.month, now.day + 1),
                        initialDateRange: range,
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          range = picked;
                          bytes = null;
                          error = null;
                        });
                      }
                    },
              icon: const Icon(Icons.date_range),
              label: Text('${dateOnly(range.start)} to ${dateOnly(range.end)}'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (bytes == null)
              FilledButton(
                onPressed: busy ? null : generate,
                child: Text(busy ? 'Preparing…' : 'Prepare PDF'),
              )
            else ...[
              FilledButton.icon(
                onPressed: busy ? null : () => export(false),
                icon: const Icon(Icons.download),
                label: const Text('Download / save PDF'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => export(true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print PDF'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
