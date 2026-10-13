import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../data/datasources/supabase_client_provider.dart';

class ChatMessage {
  const ChatMessage({
    required this.sequence,
    required this.userId,
    required this.name,
    required this.body,
    required this.createdAt,
    required this.isLeader,
    this.removed = false,
    this.hidden = false,
  });
  final int sequence;
  final String userId, name, body;
  final DateTime createdAt;
  final bool isLeader, removed, hidden;
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    sequence: j['sequence'] as int,
    userId: j['user_id'] as String,
    name: j['sender_name'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    isLeader: j['is_leader'] as bool,
    removed: j['removed'] == true,
    hidden: j['hidden'] == true,
  );
}

abstract class ChatRepository {
  Future<Result<void>> remove(
    String groupId,
    int sequence, {
    required bool everyone,
  });
  Future<Result<List<ChatMessage>>> list(String groupId, {int? before});
  Future<Result<int>> send(String groupId, String requestId, String body);
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => SupabaseChatRepository(ref.watch(supabaseClientProvider)),
);

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this.client);
  final SupabaseClient client;
  Future<Result<T>> request<T>(Future<T> Function() action) async {
    try {
      return Result.success(
        await action().timeout(const Duration(seconds: 15)),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return const Result.failure(
          PermissionFailure('Only members of this group can access its chat.'),
        );
      }
      if (e.code == '22023') {
        return const Result.failure(
          ValidationFailure(
            'Use 1–2,000 characters. If you sent many messages, wait a minute and retry.',
          ),
        );
      }
      return const Result.failure(
        ServerFailure('Group chat is unavailable. Please try again.'),
      );
    } catch (_) {
      return const Result.failure(
        NetworkFailure(
          'Could not connect to chat. Your unsent message is still here.',
        ),
      );
    }
  }

  @override
  Future<Result<List<ChatMessage>>> list(String groupId, {int? before}) =>
      request(() async {
        final rows = await client.rpc(
          'list_group_messages',
          params: {'p_group_id': groupId, 'p_before': before},
        );
        return (rows as List)
            .map(
              (j) => ChatMessage.fromJson(Map<String, dynamic>.from(j as Map)),
            )
            .toList();
      });
  @override
  Future<Result<void>> remove(
    String groupId,
    int sequence, {
    required bool everyone,
  }) => request(() async {
    await client.rpc(
      'remove_group_message',
      params: {
        'p_group_id': groupId,
        'p_sequence': sequence,
        'p_everyone': everyone,
      },
    );
  });
  @override
  Future<Result<int>> send(String groupId, String requestId, String body) =>
      request(
        () async =>
            (await client.rpc(
                  'send_group_message',
                  params: {
                    'p_group_id': groupId,
                    'p_request_id': requestId,
                    'p_body': body.trim(),
                  },
                ))
                as int,
      );
}
