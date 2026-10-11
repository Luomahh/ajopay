import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'receipt_service.dart';

Future<void> showReceipt(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final result = await ref.read(receiptServiceProvider).signedUrl(path);
  if (!context.mounted) return;
  result.when(
    failure: (f) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(f.message))),
    success: (url) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: SizedBox(
            width: 700,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Payment screenshot'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      tooltip: 'Close receipt',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'The image could not load. Close and reopen the receipt to retry.',
                        ),
                      ),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Check actual receipt of funds before confirming.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
