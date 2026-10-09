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
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
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
