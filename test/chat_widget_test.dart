import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/features/chat/chat_repository.dart';
import 'package:ajopay/features/chat/group_chat_screen.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'support/fake_group_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

class FakeChat implements ChatRepository {
  final messages = <ChatMessage>[];
  final requests = <String>[];
  int? lastReply;
  bool fail = false;
  @override
  Future<Result<void>> remove(
    String groupId,
    int sequence, {
    required bool everyone,
  }) async {
    final i = messages.indexWhere((m) => m.sequence == sequence);
    final m = messages[i];
    messages[i] = ChatMessage(
      sequence: m.sequence,
      userId: m.userId,
      name: m.name,
      body: everyone ? 'Message removed' : '',
      createdAt: m.createdAt,
      isLeader: m.isLeader,
      removed: everyone,
      hidden: !everyone,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> list(String groupId, {int? before}) async =>
      Result.success(List.of(messages));
  @override
  Future<Result<int>> send(
    String groupId,
    String requestId,
    String body, {
    int? replyTo,
  }) async {
    requests.add(requestId);
    lastReply = replyTo;
    if (fail) return const Result.failure(NetworkFailure('Send interrupted'));
    messages.add(
      ChatMessage(
        sequence: messages.length + 1,
        userId: 'member',
        name: 'Tunde',
        body: body,
        createdAt: DateTime(2026, 10, 10),
        isLeader: false,
      ),
    );
    return Result.success(messages.length);
  }
}

void main() {
  Future<FakeChat> launch(WidgetTester tester) async {
    final repo = FakeChat();
    final auth = FakeAuthRepository()..currentUserId = 'member';
    addTearDown(() => auth.changes.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(
            FakeGroupRepository()
              ..groups.add(
                SavingsGroup(
                  id: 'group',
                  name: 'October circle',
                  contributionKobo: 1000000,
                  memberLimit: 2,
                  firstPayoutDate: DateTime(2026, 10, 20),
                  status: 'active',
                ),
              ),
          ),
          chatRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: GroupChatScreen(groupId: 'group')),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('emoji, unsend and delete for me work at a narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await launch(tester);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Insert 😀'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '😀',
    );
    await tester.tap(find.byTooltip('Emoji'));
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete for everybody'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete for everybody'));
    await tester.pumpAndSettle();
    expect(find.text('Message removed'), findsOneWidget);
    expect(repo.messages.single.removed, isTrue);
    await tester.longPress(find.byKey(const ValueKey('message-1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete for everybody'), findsNothing);
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete for me'));
    await tester.pumpAndSettle();
    expect(find.text('Message removed'), findsNothing);
    expect(repo.messages.single.hidden, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('group title and long press reply preserve the parent', (
    tester,
  ) async {
    final repo = await launch(tester);
    expect(find.text('October circle'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Original');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Message options'), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('message-1')));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Reply to yourself'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Reply');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(repo.lastReply, 1);
    expect(find.text('Reply to yourself'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'chat preserves draft and request id after failure, then displays sent message',
    (tester) async {
      final repo = await launch(tester);
      repo.fail = true;
      await tester.enterText(find.byType(TextField), 'Hello my circle');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Send interrupted'), findsOneWidget);
      expect(find.text('Hello my circle'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(repo.requests[0], repo.requests[1]);
      expect(repo.messages, hasLength(1));
      expect(find.text('You'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('empty chat message is not sent and incoming messages refresh', (
    tester,
  ) async {
    final repo = await launch(tester);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    repo.messages.add(
      ChatMessage(
        sequence: 1,
        userId: 'owner',
        name: 'Ada',
        body: 'Welcome everyone',
        createdAt: DateTime(2026, 10, 10),
        isLeader: true,
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Ada · Leader'), findsOneWidget);
    expect(find.text('Welcome everyone'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('switching groups clears the previous conversation and draft', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..currentUserId = 'member';
    final repo = FakeChat()
      ..messages.add(
        ChatMessage(
          sequence: 1,
          userId: 'owner',
          name: 'Ada',
          body: 'First group only',
          createdAt: DateTime(2026, 10, 10),
          isLeader: true,
        ),
      );
    final group = ValueNotifier('first');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: group,
            builder: (_, id, _) => GroupChatScreen(groupId: id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Private draft');
    expect(find.text('First group only'), findsOneWidget);
    repo.messages.clear();
    group.value = 'second';
    await tester.pumpAndSettle();
    expect(find.text('First group only'), findsNothing);
    expect(find.text('Private draft'), findsNothing);
    expect(
      find.text('No messages yet. Start the conversation with your circle.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    group.dispose();
    await auth.changes.close();
  });
  testWidgets('chat fits a small screen with keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
