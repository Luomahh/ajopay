import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

class SignUpController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<SignUpOutcome>> submit({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
    return result;
  }
}

final signUpControllerProvider = AsyncNotifierProvider<SignUpController, void>(
  SignUpController.new,
);
