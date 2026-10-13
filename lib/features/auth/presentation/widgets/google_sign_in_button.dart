import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/auth_providers.dart';

final googleSignInAvailableProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('GOOGLE_SIGN_IN_ENABLED', defaultValue: false),
);

class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, this.disabled = false});
  final bool disabled;
  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends ConsumerState<GoogleSignInButton> {
  bool busy = false;
  Future<void> signIn() async {
    if (busy || widget.disabled) return;
    if (!ref.read(googleSignInAvailableProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google sign-in is not available yet. Please use email for now.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!mounted) return;
    setState(() => busy = false);
    result.when(
      success: (_) {},
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy || widget.disabled ? null : signIn,
    icon: const Icon(Icons.login_rounded),
    label: Text(busy ? 'Opening Google…' : 'Continue with Google'),
  );
}
