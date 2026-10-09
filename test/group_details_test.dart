import 'package:ajopay/app/router.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/domain/entities/group_details.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_group_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

void main() {
  test('calendar monthly dates recover after short months', () {
    expect(
      contributionDate(DateTime(2028, 1, 31), SavingsFrequency.monthly, 1),
      DateTime.utc(2028, 2, 29),
    );
    expect(
      contributionDate(DateTime(2028, 1, 31), SavingsFrequency.monthly, 2),
      DateTime.utc(2028, 3, 31),
    );
    expect(
      scheduledContributions(
        DateTime(2028, 1, 1),
        DateTime(2028, 1, 15),
        SavingsFrequency.weekly,
      ),
      3,
    );
  });

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String user = 'owner',
    bool full = true,
    bool agreed = false,
    Failure? failure,
  }) async {
    final auth = FakeAuthRepository()..currentUserId = user;
    final group = SavingsGroup(
      id: 'circle',
      name: 'Friends circle',
      contributionKobo: 500000,
      memberLimit: 2,
      firstPayoutDate: DateTime.now().add(const Duration(days: 30)),
      endDate: DateTime.now().add(const Duration(days: 60)),
      mode: SavingsMode.target,
      frequency: SavingsFrequency.weekly,
      status: 'draft',
      inviteCode: 'invite',
    );
    final repo = FakeGroupRepository()
      ..groups.add(group)
      ..detailFailure = failure;
    repo.detail = GroupDetails(
      group: group,
      ownerId: 'owner',
      version: 1,
      orderPrepared: false,
      members: [
        GroupMember(
          userId: 'owner',
          name: 'Ada',
          role: 'owner',
          acceptedVersion: agreed ? 1 : null,
        ),
        if (full)
          GroupMember(
            userId: 'member',
            name: 'Tunde',
            role: 'member',
            acceptedVersion: agreed ? 1 : null,
          ),
      ],
      periods: const [],
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        groupRepositoryProvider.overrideWithValue(repo),
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
    container.read(routerProvider).go('/groups/circle');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('partial group cannot agree or activate', (tester) async {
    await launch(tester, full: false);
    await tester.ensureVisible(find.text('Activate group'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activate group'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Confirm my agreement'), findsNothing);
    expect(
      find.text('Fill every member place before confirming terms.'),
      findsOneWidget,
    );
  });
  testWidgets('member explicitly checks agreement and cannot activate', (
    tester,
  ) async {
    await launch(tester, user: 'member');
    await tester.ensureVisible(find.text('Confirm my agreement'));
    final button = find.widgetWithText(FilledButton, 'Confirm my agreement');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.text('Activate group'), findsNothing);
  });
  testWidgets('leader activation requires confirmation', (tester) async {
    await launch(tester, agreed: true);
    await tester.ensureVisible(find.text('Activate group'));
    await tester.tap(find.text('Activate group'));
    await tester.pumpAndSettle();
    expect(find.text('Activate this circle?'), findsOneWidget);
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(find.text('Activate this circle?'), findsNothing);
  });
  testWidgets('details network failure is recoverable without sign out', (
    tester,
  ) async {
    final c = await launch(tester, failure: const NetworkFailure('Offline'));
    expect(find.text('Offline'), findsOneWidget);
    (c.read(groupRepositoryProvider) as FakeGroupRepository).detailFailure =
        null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Friends circle'), findsOneWidget);
    expect(
      c.read(routerProvider).routeInformationProvider.value.uri.path,
      '/groups/circle',
    );
  });
  testWidgets('activation failure can retry and displays active state', (
    tester,
  ) async {
    final c = await launch(tester, agreed: true);
    final repo = c.read(groupRepositoryProvider) as FakeGroupRepository;
    repo.actionFailure = const NetworkFailure('Try again shortly');
    Future<void> activate() async {
      await tester.ensureVisible(find.text('Activate group'));
      await tester.tap(find.text('Activate group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
    }

    await activate();
    expect(find.text('Try again shortly'), findsOneWidget);
    repo.actionFailure = null;
    await activate();
    expect(find.text('YOUR CIRCLE IS ACTIVE'), findsOneWidget);
    expect(find.text('Activate group'), findsNothing);
    expect(repo.activatedVersions, [1, 1]);
  });

  testWidgets('details fits narrow mobile layout', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);
    await tester.ensureVisible(find.text('Activate group'));
    expect(tester.takeException(), isNull);
  });
}
