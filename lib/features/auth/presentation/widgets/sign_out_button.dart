import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';

class SignOutButton extends ConsumerStatefulWidget {
  const SignOutButton({super.key});
  @override
  ConsumerState<SignOutButton> createState() => _SignOutState();
}

class _SignOutState extends ConsumerState<SignOutButton> {
  bool busy = false;
  Future<void> logout() async {
    if (busy) return;
    setState(() => busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of AjoPay?'),
        content: const Text(
          'You can sign in again to access your circles and payment records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      final result = await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      result.when(
        success: (_) {},
        failure: (f) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message))),
      );
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Sign out',
    onPressed: busy ? null : logout,
    icon: const Icon(Icons.logout_rounded),
  );
}
