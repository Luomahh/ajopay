import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';

final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  if (ref.watch(sessionUserIdProvider) == null) {
    return {'items': [], 'unread': 0};
  }
  final data = await ref
      .watch(supabaseClientProvider)
      .rpc('get_member_notifications')
      .timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(data as Map);
});
final reminderPreferencesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final id = ref.watch(sessionUserIdProvider);
      if (id == null) return {};
      final data = await ref
          .watch(supabaseClientProvider)
          .from('notification_preferences')
          .select()
          .eq('user_id', id)
          .maybeSingle();
      return data ?? {};
    });

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});
  @override
  ConsumerState<NotificationBell> createState() => _BellState();
}

class _BellState extends ConsumerState<NotificationBell> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(notificationsProvider);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(notificationsProvider);
    final count = data.asData?.value['unread'] as int? ?? 0;
    return IconButton(
      tooltip: count > 0 ? 'Notifications ($count unread)' : 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);
    Future<void> mark(int? id) async {
      await ref
          .read(supabaseClientProvider)
          .rpc('mark_notification_read', params: {'p_id': id})
          .timeout(const Duration(seconds: 15));
      ref.invalidate(notificationsProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await mark(null);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not update notifications. Try again.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notificationsProvider),
            child: const Text('Retry notifications'),
          ),
        ),
        data: (data) {
          final items = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Recent activity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'You’re all caught up. Messages, payment updates and reminders will appear here.',
                    ),
                  ),
                for (final n in items)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        n['kind'] == 'chat'
                            ? Icons.chat_bubble_outline
                            : Icons.receipt_long_outlined,
                      ),
                      title: Text(
                        n['title'] as String,
                        style: TextStyle(
                          fontWeight: n['read_at'] == null
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(n['body'] as String),
                      trailing: n['read_at'] == null
                          ? const Icon(Icons.circle, size: 9)
                          : null,
                      onTap: () async {
                        try {
                          await mark(n['id'] as int);
                          if (context.mounted) {
                            context.push(
                              '/groups/${n['group_id']}/${n['kind'] == 'chat' ? 'chat' : 'contributions'}',
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not open this notification. Try again.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                if (items.length == 100)
                  const Text(
                    'Showing your 100 most recent notifications. Group screens retain the full records.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ReminderPreferences extends ConsumerStatefulWidget {
  const ReminderPreferences({super.key});
  @override
  ConsumerState<ReminderPreferences> createState() => _PreferencesState();
}

class _PreferencesState extends ConsumerState<ReminderPreferences> {
  bool saving = false;
  Future<void> save(Map<String, dynamic> row, String key, bool value) async {
    final id = ref.read(sessionUserIdProvider);
    if (id == null || saving) return;
    setState(() => saving = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .from('notification_preferences')
          .upsert({
            'user_id': id,
            'email_enabled': row['email_enabled'] == true,
            'sms_enabled': row['sms_enabled'] == true,
            key: value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(const Duration(seconds: 15));
      ref.invalidate(reminderPreferencesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save reminder preferences.')),
        );
      }
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(reminderPreferencesProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(reminderPreferencesProvider),
          child: const Text('Retry reminder preferences'),
        ),
        data: (row) => ExpansionTile(
          title: const Text('Email & SMS reminders'),
          subtitle: const Text('Optional · delivery setup pending'),
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Choose whether AjoPay may send payment reminders and payment-status updates to your account email or phone. Sending is not enabled yet. You can turn either channel off here at any time.',
              ),
            ),
            SwitchListTile(
              title: const Text('Email reminders'),
              value: row['email_enabled'] == true,
              onChanged: saving ? null : (v) => save(row, 'email_enabled', v),
            ),
            SwitchListTile(
              title: const Text('SMS reminders'),
              value: row['sms_enabled'] == true,
              onChanged: saving ? null : (v) => save(row, 'sms_enabled', v),
            ),
          ],
        ),
      );
}
