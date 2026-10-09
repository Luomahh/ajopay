import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import 'auth_providers.dart';

class SignInController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<void>> submit({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signIn(email: email, password: password);
    state = result.when(
      success: (_) => const AsyncData(null),
      failure: (f) => AsyncError(f, StackTrace.current),
    );
    return result;
  }
}

final signInControllerProvider = AsyncNotifierProvider<SignInController, void>(
  SignInController.new,
);
