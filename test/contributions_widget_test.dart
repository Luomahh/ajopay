import 'package:ajopay/app/router.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:ajopay/domain/entities/group_details.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/features/contributions/contribution_providers.dart';
import 'package:ajopay/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_group_repository.dart';
import 'support/fake_contribution_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

void main() {
  final today = DateTime(2026, 10, 8);
  final open = ContributionPeriod(
    number: 1,
    opensOn: today.subtract(const Duration(days: 3)),
    dueDate: today.add(const Duration(days: 3)),
  );
  final future = ContributionPeriod(
    number: 2,
    opensOn: today.add(const Duration(days: 4)),
    dueDate: today.add(const Duration(days: 10)),
  );
  final pending = Contribution(
    userId: 'member',
    period: 1,
    amountKobo: 500000,
    reference: 'transfer-123',
    paidOn: today,
    status: 'pending',
    version: 1,
  );
  late FakeContributionRepository payments;
  late ProviderContainer container;
  Future<void> launch(
    WidgetTester tester, {
    String user = 'member',
    List<Contribution> records = const [],
    Failure? failure,
  }) async {
    final auth = FakeAuthRepository()..currentUserId = user;
    final g = SavingsGroup(
      id: 'circle',
      ownerId: 'owner',
      name: 'Weekly circle',
      contributionKobo: 500000,
      memberLimit: 2,
      firstPayoutDate: open.dueDate,
      frequency: SavingsFrequency.weekly,
      status: 'active',
    );
    final groups = FakeGroupRepository()
      ..groups.add(g)
      ..detail = GroupDetails(
        group: g,
        ownerId: 'owner',
        version: 2,
        orderPrepared: true,
        members: const [
          GroupMember(
            userId: 'owner',
            name: 'Ada',
            role: 'owner',
            position: 1,
            acceptedVersion: 2,
          ),
          GroupMember(
            userId: 'member',
            name: 'Tunde',
            role: 'member',
            position: 2,
            acceptedVersion: 2,
          ),
        ],
        periods: [
          GroupPeriod(number: 1, date: open.dueDate),
          GroupPeriod(number: 2, date: future.dueDate),
        ],
      );
    payments = FakeContributionRepository(
      ContributionTracker(
        today: today,
        periods: [open, future],
        contributions: records,
        history: records,
      ),
      userId: user,
    )..failure = failure;
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        groupRepositoryProvider.overrideWithValue(groups),
        contributionRepositoryProvider.overrideWithValue(payments),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AjoPayApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/groups/circle/contributions');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'member records before deadline and cannot review or submit twice',
    (tester) async {
      await launch(tester);
      expect(find.text('MEMBER · MY SAVINGS'), findsOneWidget);
      expect(find.text('Group payment review'), findsNothing);
      await tester.ensureVisible(find.text('Record my payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record my payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(payments.submissions, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Transfer reference'),
        'transfer-123',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(payments.submissions, 1);
      expect(find.text('Awaiting review'), findsOneWidget);
      expect(find.text('Record my payment'), findsNothing);
      expect(find.text('Confirm receipt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('leader confirms receipt and total counts confirmed only', (
    tester,
  ) async {
    await launch(tester, user: 'owner', records: [pending]);
    await tester.ensureVisible(find.text('Confirm receipt'));
    await tester.pumpAndSettle();
    expect(
      find.text('NGN 0.00 confirmed of NGN 10,000.00 expected'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm receipt'));
    await tester.pumpAndSettle();
    expect(payments.reviews, 0);
    await tester.tap(find.text('Yes, received'));
    await tester.pumpAndSettle();
    expect(payments.reviews, 1);
    expect(
      find.text('NGN 5,000.00 confirmed of NGN 10,000.00 expected'),
      findsOneWidget,
    );
    expect(find.text('Confirm receipt'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('return requires a reason and member can correct report', (
    tester,
  ) async {
    await launch(tester, user: 'owner', records: [pending]);
    await tester.ensureVisible(find.text('Return for correction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return for correction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send back'));
    await tester.pumpAndSettle();
    expect(payments.reviews, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason for correction'),
      'Please check reference',
    );
    await tester.tap(find.text('Send back'));
    await tester.pumpAndSettle();
    expect(
      payments.tracker.payment(1, 'member')!.note,
      'Please check reference',
    );
    (container.read(authRepositoryProvider) as FakeAuthRepository).setUser(
      'member',
    );
    payments.userId = 'member';
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Correct payment record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correct payment record'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Transfer reference'),
      'corrected-123',
    );
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(payments.tracker.payment(1, 'member')!.version, 2);
    expect(payments.tracker.payment(1, 'member')!.status, 'pending');
  });
  testWidgets('failed confirmation keeps payment pending and can retry', (
    tester,
  ) async {
    await launch(tester, user: 'owner', records: [pending]);
    payments.failure = const NetworkFailure('Connection interrupted');
    Future<void> confirm() async {
      await tester.ensureVisible(find.text('Confirm receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm receipt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, received'));
      await tester.pumpAndSettle();
    }

    await confirm();
    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(payments.tracker.payment(1, 'member')!.status, 'pending');
    payments.failure = null;
    await confirm();
    expect(payments.tracker.payment(1, 'member')!.status, 'confirmed');
    expect(payments.reviews, 2);
  });

  testWidgets('future period cannot be submitted', (tester) async {
    await launch(tester);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 · Due 2026-10-18').last);
    await tester.pumpAndSettle();
    expect(find.text('Record my payment'), findsNothing);
    expect(find.text('Recording opens on 2026-10-12.'), findsOneWidget);
  });
  testWidgets('network failure can retry without leaving account', (
    tester,
  ) async {
    await launch(tester, failure: const NetworkFailure('Offline'));
    expect(find.text('Offline'), findsOneWidget);
    payments.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBER · MY SAVINGS'), findsOneWidget);
  });
  testWidgets('narrow layout and keyboard remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);
    await tester.ensureVisible(find.text('Record my payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record my payment'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
