import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../groups/group_providers.dart';
import '../notifications/notifications.dart';
import '../../data/datasources/supabase_client_provider.dart';
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
  ChatMessage? reply;
  int? requestReply;
  bool fetching = false,
      sending = false,
      initial = true,
      more = true,
      foreground = true,
      emojiOpen = false,
      removing = false;
  String? error, sendError, requestBody, requestId, user;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 30) {
        markVisibleChatRead();
      }
    });
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
      lastRead = 0;
      text.clear();
      reply = null;
      requestId = null;
      requestBody = null;
      fetching = false;
      sending = false;
      initial = true;
      error = null;
      sendError = null;
      more = true;
      removing = false;
      emojiOpen = false;
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
    if (fetching || removing || user == null) return;
    fetching = true;
    final epoch = generation;
    final nearBottom =
        !scroll.hasClients ||
        scroll.position.maxScrollExtent - scroll.offset < 100;
    final previousExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : 0.0;
    final previousOffset = scroll.hasClients ? scroll.offset : 0.0;
    var result = await ref
        .read(chatRepositoryProvider)
        .list(
          widget.groupId,
          before: older && messages.isNotEmpty
              ? messages.keys.reduce((a, b) => a < b ? a : b)
              : null,
        );
    // Refresh loaded history too, so removals never remain stale below page one.
    if (!older && result is Success<List<ChatMessage>> && messages.isNotEmpty) {
      final oldest = messages.keys.reduce((a, b) => a < b ? a : b);
      final refreshed = [...result.value];
      var page = result.value;
      while (page.length == 50 && page.first.sequence > oldest) {
        if (!mounted || generation != epoch) return;
        final next = await ref
            .read(chatRepositoryProvider)
            .list(widget.groupId, before: page.first.sequence);
        if (next is! Success<List<ChatMessage>>) {
          result = next;
          break;
        }
        page = next.value;
        refreshed.addAll(page);
      }
      if (result is Success<List<ChatMessage>>) {
        result = Result.success(refreshed);
      }
    }
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
          if (older || messages.length == rows.length) {
            more = rows.length >= 50 && rows.length % 50 == 0;
          }
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
        markVisibleChatRead();
      }
    });
  }

  int lastRead = 0;
  Future<void> markVisibleChatRead() async {
    if (messages.isEmpty || user == null) return;
    final through = messages.keys.reduce((a, b) => a > b ? a : b);
    if (through <= lastRead) return;
    lastRead = through;
    final epoch = generation;
    try {
      await ref
          .read(supabaseClientProvider)
          .rpc(
            'mark_chat_read',
            params: {'p_group_id': widget.groupId, 'p_through': through},
          )
          .timeout(const Duration(seconds: 10));
      if (mounted && epoch == generation) ref.invalidate(notificationsProvider);
    } catch (_) {
      if (mounted && epoch == generation) lastRead = 0;
    }
  }

  Future<void> send() async {
    final body = text.text.trim();
    if (sending || removing || body.isEmpty) return;
    if (body.length > 2000) {
      setState(() => sendError = 'Keep your message within 2,000 characters.');
      return;
    }
    if (requestBody != body || requestReply != reply?.sequence) {
      requestBody = body;
      requestReply = reply?.sequence;
      requestId = newRequestId();
    }
    final epoch = generation;
    setState(() {
      sending = true;
      sendError = null;
    });
    final result = await ref
        .read(chatRepositoryProvider)
        .send(widget.groupId, requestId!, body, replyTo: requestReply);
    if (!mounted || generation != epoch) return;
    setState(() {
      sending = false;
      result.when(
        success: (_) {
          text.clear();
          reply = null;
          requestBody = null;
          requestId = null;
        },
        failure: (f) => sendError = f.message,
      );
    });
    if (result is Success<int>) await load();
  }

  Future<void> removeMessage(ChatMessage message, bool everyone) async {
    final epoch = generation;
    if (removing) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(everyone ? 'Delete for everybody?' : 'Delete for you?'),
        content: Text(
          everyone
              ? 'Your message will be replaced by “Message removed” for everyone. Someone may already have read or copied it.'
              : 'This message will be hidden from your account. Other members will still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(everyone ? 'Delete for everybody' : 'Delete for me'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || epoch != generation) return;
    generation++;
    final mutationEpoch = generation;
    setState(() {
      removing = true;
      fetching = false;
    });
    final result = await ref
        .read(chatRepositoryProvider)
        .remove(widget.groupId, message.sequence, everyone: everyone);
    if (!mounted || mutationEpoch != generation) return;
    setState(() {
      removing = false;
      result.when(
        success: (_) {
          if (reply?.sequence == message.sequence) reply = null;
          messages[message.sequence] = ChatMessage(
            sequence: message.sequence,
            userId: message.userId,
            name: message.name,
            body: 'Message removed',
            createdAt: message.createdAt,
            isLeader: message.isLeader,
            removed: everyone,
            hidden: !everyone,
          );
        },
        failure: (f) => sendError = f.message,
      );
    });
  }

  void insertEmoji(String emoji) {
    final selection = text.selection;
    final start = selection.isValid ? selection.start : text.text.length;
    final end = selection.isValid ? selection.end : text.text.length;
    final updated = text.text.replaceRange(start, end, emoji);
    if (updated.length > 2000) return;
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> messageActions(ChatMessage m, BuildContext anchor) async {
    if (removing || sending) return;
    final epoch = generation;
    final box = anchor.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          origin.dx,
          origin.dy + box.size.height,
          box.size.width,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        if (!m.removed)
          const PopupMenuItem(value: 'reply', child: Text('Reply')),
        if (!m.removed) const PopupMenuItem(value: 'copy', child: Text('Copy')),
        const PopupMenuItem(value: 'hide', child: Text('Delete for me')),
        if (m.userId == user && !m.removed)
          const PopupMenuItem(
            value: 'everyone',
            child: Text('Delete for everybody'),
          ),
      ],
    );
    if (!mounted || epoch != generation || action == null) return;
    final current = messages[m.sequence];
    if (current == null || current.hidden) return;
    if (action == 'reply' && !current.removed) {
      setState(() => reply = current);
    }
    if (action == 'copy' && !current.removed) {
      await Clipboard.setData(ClipboardData(text: current.body));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message copied.')));
      }
    }
    if (action == 'hide' || action == 'everyone') {
      await removeMessage(current, action == 'everyone');
    }
  }

  Widget bubble(ChatMessage m) {
    final mine = m.userId == user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .9,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Builder(
            builder: (bubbleContext) => Semantics(
              button: true,
              label: 'Message from ${m.name}. Hold for actions',
              onLongPress: () => messageActions(m, bubbleContext),
              child: GestureDetector(
                key: ValueKey('message-${m.sequence}'),
                onLongPress: () => messageActions(m, bubbleContext),
                onSecondaryTap: () => messageActions(m, bubbleContext),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                  decoration: BoxDecoration(
                    color: mine ? AjoColors.mint : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 3),
                      bottomRight: Radius.circular(mine ? 3 : 16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${mine ? 'You' : m.name}${m.isLeader ? ' · Leader' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AjoColors.forest,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (m.replyTo != null && !m.removed)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x0F123F35),
                            border: const Border(
                              left: BorderSide(
                                color: AjoColors.emerald,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            m.replyBody ?? 'Message unavailable',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      Text(
                        m.body,
                        style: TextStyle(
                          fontSize: 15,
                          fontStyle: m.removed
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: m.removed ? AjoColors.muted : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stamp(m.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AjoColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailsProvider(widget.groupId));
    final groupName =
        group.asData?.value.when(
          success: (details) => details.group.name,
          failure: (_) => 'Your circle',
        ) ??
        'Your circle';
    final identity = ref.watch(sessionUserIdProvider);
    if (identity != user) {
      user = identity;
      generation++;
      messages.clear();
      lastRead = 0;
      text.clear();
      reply = null;
      requestReply = null;
      requestId = null;
      requestBody = null;
      fetching = false;
      sending = false;
      initial = true;
      error = null;
      sendError = null;
      more = true;
      removing = false;
      emojiOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
    final rows = messages.values.where((m) => !m.hidden).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4EF),
      appBar: AppBar(
        backgroundColor: AjoColors.forest,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text(
              'Members only',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          tooltip: 'Group details',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/groups/${widget.groupId}');
            }
          },
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
                            if (more && messages.isNotEmpty)
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
                            for (var i = 0; i < rows.length; i++) ...[
                              if (i == 0 ||
                                  day(rows[i].createdAt) !=
                                      day(rows[i - 1].createdAt))
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white70,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      day(rows[i].createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AjoColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              bubble(rows[i]),
                            ],
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
                if (reply != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.reply),
                    title: Text(
                      'Reply to ${reply!.userId == user ? 'yourself' : reply!.name}',
                    ),
                    subtitle: Text(
                      messages[reply!.sequence]?.removed == true
                          ? 'Message removed'
                          : reply!.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: sending
                          ? null
                          : () => setState(() => reply = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                if (emojiOpen)
                  SizedBox(
                    height: 110,
                    child: SingleChildScrollView(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (final emoji in [
                            '😀',
                            '😊',
                            '😂',
                            '❤️',
                            '👍',
                            '🙏',
                            '🎉',
                            '✅',
                            '💚',
                            '💰',
                            '👋',
                            '🤝',
                            '🙌',
                            '👏',
                            '🤔',
                            '😅',
                          ])
                            IconButton(
                              tooltip: 'Insert $emoji',
                              onPressed: sending
                                  ? null
                                  : () => insertEmoji(emoji),
                              icon: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Emoji',
                        onPressed: () => setState(() => emojiOpen = !emojiOpen),
                        icon: Icon(
                          emojiOpen
                              ? Icons.keyboard_outlined
                              : Icons.emoji_emotions_outlined,
                        ),
                      ),
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
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
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

  String day(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  String stamp(DateTime date) {
    final d = date.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
