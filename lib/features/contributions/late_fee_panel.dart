import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../../domain/entities/group_details.dart';
import '../../domain/entities/savings_group.dart';
import '../../core/widgets/ajo_ui.dart';
import '../auth/application/auth_providers.dart';

final lateFeesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
      if (ref.watch(sessionUserIdProvider) == null) return [];
      final rows = await ref
          .watch(supabaseClientProvider)
          .rpc('get_late_fees', params: {'p_group_id': id})
          .timeout(const Duration(seconds: 15));
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    });

class LateFeePanel extends ConsumerWidget {
  const LateFeePanel({super.key, required this.details});
  final GroupDetails details;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AjoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Late fees · separate from savings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'NGN 200 once per missed deadline. The leader checks the actual payment date, so a late review does not penalise an on-time transfer.',
        ),
        const SizedBox(height: 12),
        ref
            .watch(lateFeesProvider(details.group.id))
            .when(
              loading: () => const Text('Checking deadlines…'),
              error: (_, _) => TextButton(
                onPressed: () =>
                    ref.invalidate(lateFeesProvider(details.group.id)),
                child: const Text('Retry fee status'),
              ),
              data: (rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rows.isEmpty)
                    const Text('No late fees currently listed.'),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${details.member(r['user_id'] as String)?.name ?? 'Member'} · period ${r['period_number']} · ${formatNaira(r['amount_kobo'] as int)} · ${r['status'] == 'due' ? 'due' : 'payment date awaiting review'}',
                      ),
                    ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        const Text(
          'Late-fee collection is paused. Unpaid fees do not block contributions or payouts. Do not add fees to the group bank transfer or subtract them from savings.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
