import 'package:flutter/foundation.dart';
import '../../core/utils/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Stream<String?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) => data.session?.user.id);
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  bool get needsContactDetails {
    final user = _client.auth.currentUser;
    return user != null &&
        (Validators.phone(user.userMetadata?['contact_phone'] as String?) !=
                null ||
            Validators.fullName(user.userMetadata?['full_name'] as String?) !=
                null);
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri(
                scheme: Uri.base.scheme,
                host: Uri.base.host,
                port: Uri.base.hasPort ? Uri.base.port : null,
                path: Uri.base.path,
              ).toString()
            : 'com.luomah.ajopay://login-callback/',
        queryParams: {'prompt': 'select_account'},
      );
      return launched
          ? const Result.success(null)
          : const Result.failure(
              AuthFailure('Could not open Google sign-in. Please try again.'),
            );
    } on AuthException catch (e) {
      return Result.failure(AuthFailure(e.message));
    } catch (_) {
      return const Result.failure(
        NetworkFailure('Google sign-in could not start. Please try again.'),
      );
    }
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    bool sharePhone = false,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'contact_phone': Validators.normalizePhone(phone),
          'share_phone': sharePhone,
        },
      );

      return Result.success(
        response.session == null
            ? SignUpOutcome.confirmationRequired
            : SignUpOutcome.signedIn,
      );
    } on AuthRetryableFetchException {
      return const Result.failure(NetworkFailure());
    } on AuthException catch (e) {
      return Result.failure(AuthFailure(e.message));
    } catch (e) {
      return const Result.failure(ServerFailure());
    }
  }

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const Result.success(null);
    } on AuthRetryableFetchException {
      return const Result.failure(NetworkFailure());
    } on AuthException catch (e) {
      return Result.failure(AuthFailure(e.message));
    } catch (e) {
      return const Result.failure(ServerFailure());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Result.success(null);
    } catch (e) {
      return const Result.failure(ServerFailure());
    }
  }
}
