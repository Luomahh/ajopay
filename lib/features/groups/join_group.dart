import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import 'group_providers.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});
  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final code = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> join() async {
    if (busy) return;
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(code.text.trim())) {
      setState(
        () => error = 'Paste the full invite code shared by your group leader.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final result = await ref.read(groupRepositoryProvider).joinGroup(code.text);
    if (!mounted) return;
    result.when(
      success: (group) {
        ref.invalidate(groupsProvider);
        context.go('/groups/${group.id}');
      },
      failure: (f) => setState(() {
        busy = false;
        error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Join a group'),
      backgroundColor: AjoColors.forest,
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your circle is waiting.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Paste the invite code your group leader shared. You can join while the group is still a draft.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Invite code'),
                autocorrect: false,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : join,
                child: Text(busy ? 'Joining…' : 'Join group'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
