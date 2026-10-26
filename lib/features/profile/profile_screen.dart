import 'package:flutter/material.dart';
import '../../core/widgets/home_navigation.dart';
import '../notifications/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';
import '../../core/widgets/ajo_ui.dart';
import '../groups/group_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/validators.dart';
import '../auth/presentation/widgets/sign_out_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.requireCompletion = false});
  final bool requireCompletion;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      city = TextEditingController(),
      bio = TextEditingController(),
      address = TextEditingController();
  bool sharePhone = false, loaded = false;
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    address.dispose();
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
      phone.text =
          row?['phone'] as String? ??
          client.auth.currentUser?.userMetadata?['contact_phone'] as String? ??
          '';
      address.text = row?['home_address'] as String? ?? '';
      sharePhone = row?['share_phone'] as bool? ?? false;
      loaded = true;
      city.text = row?['city'] as String? ?? '';
      bio.text = row?['bio'] as String? ?? '';
      error = null;
    } catch (_) {
      error = 'Your profile could not load. Please try again.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (saving || !loaded || !form.currentState!.validate()) return;
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
            'phone': Validators.normalizePhone(phone.text),
            'home_address': address.text.trim(),
            'share_phone': sharePhone,
            'city': city.text.trim(),
            'bio': bio.text.trim(),
          })
          .timeout(const Duration(seconds: 15));
      await ref
          .read(supabaseClientProvider)
          .auth
          .updateUser(
            UserAttributes(
              data: {
                'full_name': name.text.trim(),
                'contact_phone': Validators.normalizePhone(phone.text),
              },
            ),
          )
          .timeout(const Duration(seconds: 15));
      ref.invalidate(groupDetailsProvider);
      if (mounted && widget.requireCompletion) {
        context.go('/dashboard');
        return;
      }
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
    appBar: AppBar(
      title: Text(
        widget.requireCompletion ? 'Complete your account' : 'Your profile',
      ),
      automaticallyImplyLeading: false,
      actions: const [SignOutButton()],
    ),
    bottomNavigationBar: widget.requireCompletion
        ? null
        : const HomeNavigation(index: 1),
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
                      if (!widget.requireCompletion)
                        const ReminderPreferences(),
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
                        'Your name, city and introduction are shared with members of your groups. Choose whether to share your phone number. Your home address is private.',
                      ),
                      const SizedBox(height: 24),
                      if (error != null) ...[
                        Text(error!),
                        TextButton(
                          onPressed: saving ? null : load,
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
                        validator: Validators.phone,
                        maxLength: 24,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Share phone number with my groups'),
                        subtitle: const Text(
                          'Members can use it to contact you. Numbers are self-reported, not verified.',
                        ),
                        value: sharePhone,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => sharePhone = v),
                      ),
                      TextFormField(
                        controller: address,
                        enabled: !saving,
                        maxLength: 300,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Home address (private, optional)',
                          helperText:
                              'Visible only in your own profile. Never included in shared profiles or PDFs.',
                          helperMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: saving || !loaded ? null : save,
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
                              'Your BVN and NIN are not collected or stored here. Secure provider verification will be added before in-app payments launch. Never put these identifiers in your introduction or chat.',
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
