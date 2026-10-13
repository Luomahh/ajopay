import '../../core/errors/result.dart';

enum SignUpOutcome { signedIn, confirmationRequired }

abstract class AuthRepository {
  /// Emits the current user's id whenever auth state changes, or null if signed out.
  Stream<String?> authStateChanges();

  String? get currentUserId;
  bool get needsContactDetails;
  Future<Result<void>> signInWithGoogle();

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    bool sharePhone = false,
  });

  Future<Result<void>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}
