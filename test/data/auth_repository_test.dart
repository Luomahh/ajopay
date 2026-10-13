import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/data/repositories/auth_repository_impl.dart';
import 'package:ajopay/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuth auth;
  late AuthRepositoryImpl repository;

  setUp(() {
    final client = MockClient();
    auth = MockAuth();
    when(() => client.auth).thenReturn(auth);
    repository = AuthRepositoryImpl(client);
  });

  Future<AuthResponse> signUpCall() => auth.signUp(
    email: 'member@example.com',
    password: 'password123',
    data: {
      'full_name': 'Ajo Member',
      'contact_phone': '+2348012345678',
      'share_phone': false,
    },
  );

  Future<Result<SignUpOutcome>> signUp() => repository.signUp(
    email: 'member@example.com',
    password: 'password123',
    fullName: 'Ajo Member',
    phone: '08012345678',
  );

  test('signup without a session requires email confirmation', () async {
    when(signUpCall).thenAnswer((_) async => AuthResponse(user: MockUser()));
    final result = await signUp() as Success<SignUpOutcome>;
    expect(result.value, SignUpOutcome.confirmationRequired);
  });

  test('signup with a session reports signed in', () async {
    when(signUpCall).thenAnswer(
      (_) async => AuthResponse(session: MockSession(), user: MockUser()),
    );
    final result = await signUp() as Success<SignUpOutcome>;
    expect(result.value, SignUpOutcome.signedIn);
  });

  test('retryable auth transport errors map to network failure', () async {
    when(signUpCall).thenThrow(AuthRetryableFetchException());
    final result = await signUp() as Error<SignUpOutcome>;
    expect(result.failure, isA<NetworkFailure>());
  });

  test('auth rejection retains the server message', () async {
    when(signUpCall).thenThrow(const AuthException('Signup is disabled'));
    final result = await signUp() as Error<SignUpOutcome>;
    expect(result.failure, isA<AuthFailure>());
    expect(result.failure.message, 'Signup is disabled');
  });
}
