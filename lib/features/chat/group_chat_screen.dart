import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/errors/result.dart';
import '../../core/utils/request_id.dart';
import '../auth/application/auth_providers.dart';
import 'chat_repository.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatState();
}

class _GroupChatState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  final text = TextEditingController();
  final scroll = ScrollController();
  final messages = <int, ChatMessage>{};
  Timer? timer;
  bool fetching = false,
      sending = false,
      initial = true,
      more = true,
      foreground = true;
  String? error, sendError, requestBody, requestId, user;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (foreground) load();
    });
  }

  @override
  void didUpdateWidget(covariant GroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      generation++;
      messages.clear();
      text.clear();
      requestId = null;
      requestBody = null;
      fetching = false;
      sending = false;
      initial = true;
      error = null;
      sendError = null;
      more = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) load();
  }

  Future<void> load({bool older = false}) async {
    if (fetching || user == null) return;
    fetching = true;
    final epoch = generation;
    final nearBottom =
        !scroll.hasClients ||
        scroll.position.maxScrollExtent - scroll.offset < 100;
    final previousExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : 0.0;
    final previousOffset = scroll.hasClients ? scroll.offset : 0.0;
    final result = await ref
        .read(chatRepositoryProvider)
        .list(
          widget.groupId,
          before: older && messages.isNotEmpty
              ? messages.keys.reduce((a, b) => a < b ? a : b)
              : null,
        );
    if (!mounted || generation != epoch) return;
    setState(() {
      fetching = false;
      initial = false;
      result.when(
        success: (rows) {
          error = null;
          // If more than one page arrived while away, restart at the latest
          // page so Load earlier can retrieve every intervening message.
          if (!older &&
              rows.length == 50 &&
              messages.isNotEmpty &&
              rows.first.sequence >
                  messages.keys.reduce((a, b) => a > b ? a : b)) {
            messages.clear();
            more = true;
          }
          for (final m in rows) {
            messages[m.sequence] = m;
          }
          if (older || messages.length == rows.length) more = rows.length == 50;
        },
        failure: (f) => error = f.message,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      if (older) {
        scroll.jumpTo(
          (previousOffset + scroll.position.maxScrollExtent - previousExtent)
              .clamp(0, scroll.position.maxScrollExtent),
        );
      } else if (nearBottom) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> send() async {
    final body = text.text.trim();
    if (sending || body.isEmpty) return;
    if (body.length > 2000) {
      setState(() => sendError = 'Keep your message within 2,000 characters.');
      return;
    }
    if (requestBody != body) {
      requestBody = body;
      requestId = newRequestId();
    }
    final epoch = generation;
    setState(() {
      sending = true;
      sendError = null;
    });
    final result = await ref
        .read(chatRepositoryProvider)
        .send(widget.groupId, requestId!, body);
    if (!mounted || generation != epoch) return;
    setState(() {
      sending = false;
      result.when(
        success: (_) {
          text.clear();
          requestBody = null;
          requestId = null;
        },
        failure: (f) => sendError = f.message,
      );
    });
    if (result is Success<int>) await load();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionUserIdProvider);
    if (identity != user) {
      user = identity;
      generation++;
      messages.clear();
      text.clear();
      requestId = null;
      requestBody = null;
      fetching = false;
      sending = false;
      initial = true;
      error = null;
      sendError = null;
      more = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
    final rows = messages.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group chat'),
        leading: IconButton(
          tooltip: 'Group details',
          onPressed: () => context.go('/groups/${widget.groupId}'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh chat',
            onPressed: fetching ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'A conversation for this circle’s members. New messages refresh automatically.',
                    style: TextStyle(color: AjoColors.muted, fontSize: 13),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(error!)),
                        TextButton(
                          onPressed: () => load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: initial
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scroll,
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (more && rows.isNotEmpty)
                              TextButton(
                                onPressed: fetching
                                    ? null
                                    : () => load(older: true),
                                child: const Text('Load earlier messages'),
                              ),
                            if (rows.isEmpty && error == null)
                              const Padding(
                                padding: EdgeInsets.all(30),
                                child: Text(
                                  'No messages yet. Start the conversation with your circle.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            for (final m in rows)
                              Align(
                                alignment: m.userId == user
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: m.userId == user
                                        ? AjoColors.mint
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.userId == user ? 'You' : m.name}${m.isLeader ? ' · Leader' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AjoColors.forest,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      SelectableText(m.body),
                                      const SizedBox(height: 6),
                                      Text(
                                        stamp(m.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AjoColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (sendError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      sendError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: text,
                          enabled: !sending,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Message your circle',
                            hintText: 'Write a message…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: sending ? null : send,
                        icon: sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String stamp(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
