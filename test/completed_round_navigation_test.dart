import 'package:ajopay/app/router.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:ajopay/domain/entities/group_details.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/contributions/contribution_providers.dart';
import 'package:ajopay/features/groups/group_providers.dart';
import 'package:ajopay/features/payouts/payout_providers.dart';
import 'package:ajopay/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_contribution_repository.dart';
import 'support/fake_group_repository.dart';
import 'support/fake_payout_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

void main() {
  testWidgets(
    'completed round retains navigable histories and sign-out protects them',
    (tester) async {
      final date = DateTime(2026, 10, 10);
      final auth = FakeAuthRepository()..currentUserId = 'member';
      final group = SavingsGroup(
        id: 'circle',
        name: 'Completed circle',
        contributionKobo: 1000000,
        memberLimit: 2,
        firstPayoutDate: date,
        status: 'completed',
        ownerId: 'owner',
      );
      final groups = FakeGroupRepository()
        ..groups.add(group)
        ..detail = GroupDetails(
          group: group,
          ownerId: 'owner',
          version: 2,
          orderPrepared: true,
          members: const [
            GroupMember(userId: 'owner', name: 'Ada', role: 'owner'),
            GroupMember(userId: 'member', name: 'Tunde', role: 'member'),
          ],
          periods: [GroupPeriod(number: 1, date: date, recipientId: 'member')],
        );
      final record = Contribution(
        userId: 'member',
        period: 1,
        amountKobo: 1000000,
        reference: 'DEMO-CONTRIBUTION',
        paidOn: date,
        status: 'confirmed',
        version: 1,
      );
      final payments = FakeContributionRepository(
        ContributionTracker(
          today: date,
          periods: [
            ContributionPeriod(number: 1, opensOn: date, dueDate: date),
          ],
          contributions: [record],
          history: [record],
        ),
        userId: 'member',
      );
      final payouts = FakePayoutRepository(
        trackerFixture(
          status: 'completed',
          rows: [payoutFixture(status: 'confirmed', version: 1)],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groups),
          contributionRepositoryProvider.overrideWithValue(payments),
          payoutRepositoryProvider.overrideWithValue(payouts),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.changes.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AjoPayApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/groups/circle');
      await tester.pumpAndSettle();
      expect(find.text('YOUR CIRCLE IS COMPLETED'), findsOneWidget);
      await tester.ensureVisible(find.text('View payout history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View payout history'));
      await tester.pumpAndSettle();
      expect(find.text('SAVINGS ROUND COMPLETED'), findsOneWidget);
      expect(find.text('I received this money'), findsNothing);
      await tester.ensureVisible(find.text('View contributions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View contributions'));
      await tester.pumpAndSettle();
      expect(find.text('Reference: DEMO-CONTRIBUTION'), findsOneWidget);
      expect(find.text('Record my payment'), findsNothing);
      expect(find.text('Correct payment record'), findsNothing);
      auth.setUser(null);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/sign-in',
      );
      expect(find.text('Reference: DEMO-CONTRIBUTION'), findsNothing);
      container.read(routerProvider).go('/groups/circle/payouts');
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/sign-in',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
