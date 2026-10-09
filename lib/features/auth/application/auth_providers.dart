import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase_client_provider.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(client);
});

/// Emits the current user id, or null if signed out.
/// The router watches this to decide whether to redirect to sign-in.
final authStateProvider = StreamProvider<String?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Only a resolved signed-out event clears identity. Transport errors do not
/// mean the session has ended; the backend still authorizes every request.
final sessionUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth is AsyncData<String?>) return auth.value;
  return ref.read(authRepositoryProvider).currentUserId;
});
