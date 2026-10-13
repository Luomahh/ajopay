import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';

final sharedProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String groupId, String userId})>((
      ref,
      key,
    ) async {
      ref.watch(sessionUserIdProvider);
      final row = await ref
          .watch(supabaseClientProvider)
          .rpc(
            'get_member_profile',
            params: {'p_group_id': key.groupId, 'p_user_id': key.userId},
          )
          .timeout(const Duration(seconds: 15));
      return row == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(row as Map);
    });

class MemberProfileDialog extends ConsumerWidget {
  const MemberProfileDialog({
    super.key,
    required this.groupId,
    required this.userId,
  });
  final String groupId, userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (groupId: groupId, userId: userId);
    return AlertDialog(
      title: const Text('Member profile'),
      content: SingleChildScrollView(
        child: ref
            .watch(sharedProfileProvider(key))
            .when(
              loading: () => const Text('Loading profile…'),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(sharedProfileProvider(key)),
                child: const Text('Could not load. Try again'),
              ),
              data: (p) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['display_name'] as String? ?? 'Member',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p['city'] as String? ?? ''),
                  Text(p['bio'] as String? ?? ''),
                  if (p['phone'] != null)
                    SelectableText('Phone: ${p['phone']} (unverified)'),
                  const SizedBox(height: 16),
                  const Text(
                    'Self-reported profile · identity not verified. A profile is not a guarantee that someone will pay.',
                  ),
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
