import 'dart:async';

import 'package:ajopay/app/router.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/domain/repositories/auth_repository.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_group_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final changes = StreamController<String?>.broadcast();
  @override
  String? currentUserId;
  @override
  bool needsContactDetails = false;
  int googleCalls = 0;
  @override
  Future<Result<void>> signInWithGoogle() async {
    googleCalls++;
    return const Result.success(null);
  }

  Failure? signInFailure;
  Failure? signOutFailure;
  int signInCalls = 0;
  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationRequired;

  @override
  Stream<String?> authStateChanges() async* {
    yield currentUserId;
    yield* changes.stream;
  }

  void setUser(String? id) {
    currentUserId = id;
    changes.add(id);
  }

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInFailure != null) return Result.failure(signInFailure!);
    setUser('test-user');
    return const Result.success(null);
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    bool sharePhone = false,
  }) async {
    if (signUpOutcome == SignUpOutcome.signedIn) setUser('test-user');
    return Result.success(signUpOutcome);
  }

  @override
  Future<Result<void>> signOut() async {
    if (signOutFailure != null) return Result.failure(signOutFailure!);
    setUser(null);
    return const Result.success(null);
  }
}

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.changes.close();
  });

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AjoPayApp()),
    );
    await tester.pumpAndSettle();
    if (repository.currentUserId == null) {
      container.read(routerProvider).go('/sign-in');
      await tester.pumpAndSettle();
    }
  }

  Future<void> fillSignUp(WidgetTester tester) async {
    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ajo Member');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), '08012345678');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out user cannot open dashboard', (tester) async {
    await launch(tester);
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('empty form is rejected before repository call', (tester) async {
    await launch(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });

  testWidgets('signed-out user cannot open group creation', (tester) async {
    await launch(tester);
    container.read(routerProvider).go('/groups/new');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.text('Create draft group'), findsNothing);
  });

  testWidgets('sign in and sign out redirect using the same router', (
    tester,
  ) async {
    await launch(tester);
    final router = container.read(routerProvider);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(container.read(routerProvider), same(router));
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(container.read(routerProvider), same(router));
  });

  testWidgets('invalid credentials show an error and permit retry', (
    tester,
  ) async {
    repository.signInFailure = const AuthFailure('Invalid login credentials');
    await launch(tester);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid login credentials'), findsOneWidget);
    repository.signInFailure = null;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets(
    'restored session opens dashboard and expiry returns to sign in',
    (tester) async {
      repository.currentUserId = 'restored-user';
      await launch(tester);
      expect(find.byTooltip('Sign out'), findsOneWidget);
      repository.setUser(null);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    },
  );

  testWidgets('sign out failure is visible and keeps dashboard', (
    tester,
  ) async {
    repository.currentUserId = 'restored-user';
    repository.signOutFailure = const NetworkFailure();
    await launch(tester);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.text(const NetworkFailure().message), findsOneWidget);
  });

  testWidgets('sign up requiring confirmation explains the next step', (
    tester,
  ) async {
    await launch(tester);
    await fillSignUp(tester);
    expect(
      find.text('Check your email to confirm your account, then sign in.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('sign up with session opens dashboard', (tester) async {
    repository.signUpOutcome = SignUpOutcome.signedIn;
    await launch(tester);
    await fillSignUp(tester);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('auth forms remain scrollable with keyboard on small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);
    await launch(tester);
    expect(tester.takeException(), isNull);
    container.read(routerProvider).go('/sign-up');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('logout cancellation preserves the session', (tester) async {
    repository.currentUserId = 'restored-user';
    await launch(tester);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(repository.currentUserId, 'restored-user');
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('signed out startup opens the landing page', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AjoPayApp()),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/',
    );
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('unconfigured Google sign in explains email fallback', (
    tester,
  ) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(repository.googleCalls, 0);
    expect(
      find.text(
        'Google sign-in is not available yet. Please use email for now.',
      ),
      findsOneWidget,
    );
  });
}
