import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';
import '../../core/widgets/ajo_ui.dart';
import '../groups/group_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      city = TextEditingController(),
      bio = TextEditingController();
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    city.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final client = ref.read(supabaseClientProvider),
          id = ref.read(sessionUserIdProvider);
      if (id == null) return;
      final row = await client
          .from('member_profiles')
          .select()
          .eq('user_id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      name.text =
          row?['display_name'] as String? ??
          client.auth.currentUser?.userMetadata?['full_name'] as String? ??
          '';
      phone.text = row?['phone'] as String? ?? '';
      city.text = row?['city'] as String? ?? '';
      bio.text = row?['bio'] as String? ?? '';
      error = null;
    } catch (_) {
      error = 'Your profile could not load. Please try again.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final id = ref.read(sessionUserIdProvider);
      if (id == null) return;
      await ref
          .read(supabaseClientProvider)
          .from('member_profiles')
          .upsert({
            'user_id': id,
            'display_name': name.text.trim(),
            'phone': phone.text.trim(),
            'city': city.text.trim(),
            'bio': bio.text.trim(),
          })
          .timeout(const Duration(seconds: 15));
      ref.invalidate(groupDetailsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      }
    } catch (_) {
      error = 'Could not save your profile. Please try again.';
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your profile')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AjoBrand(),
                      const SizedBox(height: 24),
                      const Text(
                        'Help your circle know you',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your name, city and introduction are shared with members of your groups. Your phone number stays private.',
                      ),
                      const SizedBox(height: 24),
                      if (error != null) ...[
                        Text(error!),
                        TextButton(
                          onPressed: load,
                          child: const Text('Reload profile'),
                        ),
                      ],
                      TextFormField(
                        controller: name,
                        maxLength: 80,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      TextFormField(
                        controller: city,
                        maxLength: 80,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'City (optional)',
                        ),
                      ),
                      TextFormField(
                        controller: bio,
                        maxLength: 240,
                        maxLines: 3,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Introduce yourself (optional)',
                        ),
                      ),
                      TextFormField(
                        controller: phone,
                        maxLength: 24,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number (private, optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? 'Saving…' : 'Save profile'),
                      ),
                      const SizedBox(height: 24),
                      const AjoPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined),
                            SizedBox(height: 12),
                            Text(
                              'Identity verification is not available yet',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'These details are self-reported. Do not enter your NIN in your profile, payment notes or chat. Secure identity checks will be added before in-app payments launch.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
