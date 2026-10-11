import 'package:ajopay/app/router.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_group_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

void main() {
  late FakeAuthRepository auth;
  late FakeGroupRepository groups;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository()..currentUserId = 'owner';
    groups = FakeGroupRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        groupRepositoryProvider.overrideWithValue(groups),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.changes.close();
  });

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AjoPayApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillDraft(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Group name'),
      'Friends circle',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monthly contribution (NGN)'),
      '20000.50',
    );
    await tester.ensureVisible(find.text('Choose first contribution date'));
    await tester.tap(find.text('Choose first contribution date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create draft group'));
    await tester.tap(find.text('Create draft group'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creates a draft and refreshes the dashboard with exact amounts',
    (tester) async {
      await launch(tester);
      await tester.scrollUntilVisible(find.text('No groups yet'), 150);
      expect(find.text('No groups yet'), findsOneWidget);
      await fillDraft(tester);
      expect(find.textContaining('NGN 200,005.00'), findsOneWidget);
      await save(tester);
      expect(find.text('Your savings circle'), findsOneWidget);
      await tester.ensureVisible(find.text('Friends circle'));
      expect(find.text('Friends circle'), findsOneWidget);
      expect(find.text('BUILDING YOUR CIRCLE'), findsOneWidget);
      expect(groups.lastDraft!.contributionKobo, 2000050);
      expect(groups.requests, hasLength(1));
    },
  );

  testWidgets(
    'failed save retains input and retries with the same request id',
    (tester) async {
      groups.createFailure = const NetworkFailure('Connection interrupted');
      await launch(tester);
      await fillDraft(tester);
      await save(tester);
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(find.text('Friends circle'), findsOneWidget);
      groups.createFailure = null;
      await save(tester);
      expect(groups.requests, hasLength(2));
      expect(groups.requests[0], groups.requests[1]);
      expect(find.text('Your savings circle'), findsOneWidget);
    },
  );

  testWidgets('valid invite opens group details; invalid input stays on join', (
    tester,
  ) async {
    groups.groups.add(
      SavingsGroup(
        id: 'joined',
        name: 'Joined circle',
        contributionKobo: 500000,
        memberLimit: 2,
        firstPayoutDate: DateTime.now().add(const Duration(days: 30)),
        status: 'draft',
        inviteCode: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );
    await launch(tester);
    container.read(routerProvider).go('/groups/join');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(groups.joinedCodes, isEmpty);
    expect(
      find.text('Paste the full invite code shared by your group leader.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid invite'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(find.text('Your savings circle'), findsOneWidget);
    expect(find.text('Joined circle'), findsOneWidget);
  });

  testWidgets('invalid group terms never reach the repository', (tester) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(groups.requests, isEmpty);
    expect(find.text('Enter at least 3 characters'), findsOneWidget);
  });

  testWidgets(
    'loading failure is distinct from an empty group list and can retry',
    (tester) async {
      groups.listFailure = const NetworkFailure('Connection interrupted');
      await launch(tester);
      await tester.scrollUntilVisible(find.text('Connection interrupted'), 150);
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(find.text('No groups yet'), findsNothing);
      groups.listFailure = null;
      await tester.ensureVisible(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('No groups yet'), 150);
      expect(find.text('No groups yet'), findsOneWidget);
    },
  );

  testWidgets('create form fits a small screen with the keyboard visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.reset);
    await launch(tester);
    await tester.scrollUntilVisible(find.text('Create a group'), 100);
    await tester.ensureVisible(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create draft group'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'amount entry survives auth transport errors, refresh and keyboard resize',
    (tester) async {
      await launch(tester);
      final router = container.read(routerProvider);
      await tester.ensureVisible(find.text('Create a group'));
      await tester.tap(find.text('Create a group'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Group name'),
        'Keep my draft',
      );
      auth.changes.addError(
        Exception('Temporary token refresh connection failure'),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      final amount = find.widgetWithText(
        TextFormField,
        'Monthly contribution (NGN)',
      );
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '25000');
      auth.setUser('owner');
      await tester.pumpAndSettle();
      expect(container.read(routerProvider), same(router));
      expect(find.text('Create draft group'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsNothing);
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(find.text('25000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      auth.setUser(null);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sign-in');
    },
  );
}
