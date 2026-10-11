import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/domain/entities/group_details.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:ajopay/features/contributions/payment_dialog.dart';
import 'package:ajopay/features/contributions/contribution_providers.dart';
import 'package:ajopay/features/landing/landing_screen.dart';
import 'package:ajopay/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_contribution_repository.dart';

void main() {
  test(
    'weekly contributions map to five and four deadline calendar payouts',
    () {
      final d = GroupDetails(
        group: SavingsGroup(
          id: 'g',
          name: 'Circle',
          contributionKobo: 1000000,
          memberLimit: 2,
          firstPayoutDate: DateTime.utc(2026, 1, 1),
          status: 'draft',
          rulesVersion: 2,
          frequency: SavingsFrequency.weekly,
          payoutFrequency: SavingsFrequency.monthly,
          firstCollectionDate: DateTime.utc(2026, 1, 31),
        ),
        ownerId: 'a',
        version: 1,
        orderPrepared: true,
        members: const [
          GroupMember(userId: 'a', name: 'Ada', role: 'owner', position: 1),
          GroupMember(userId: 'b', name: 'Bola', role: 'member', position: 2),
        ],
        periods: const [],
      );
      expect(d.schedule.length, 9);
      expect(d.payoutSchedule.map((p) => p.contributionCount), [5, 4]);
      expect(d.payoutSchedule.map((p) => p.amountKobo), [10000000, 8000000]);
      expect(d.payoutSchedule.last.recipientId, 'b');
    },
  );
  test('payout pace cannot be faster than contribution pace', () {
    final d = GroupDraft(
      name: 'Circle',
      contributionKobo: 1000000,
      memberLimit: 2,
      firstPayoutDate: DateTime(2027, 1, 1),
      rulesVersion: 2,
      frequency: SavingsFrequency.monthly,
      payoutFrequency: SavingsFrequency.weekly,
      firstCollectionDate: DateTime(2027, 1, 1),
    );
    expect(d.validate(DateTime(2026, 12, 1)), isNotNull);
  });
  testWidgets(
    'flexible payment rejects below minimum and sends actual amount without fee',
    (tester) async {
      final repo = FakeContributionRepository(
        ContributionTracker(
          today: DateTime(2026, 10, 11),
          periods: const [],
          contributions: const [],
          history: const [],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [contributionRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => PaymentDialog(
                      groupId: 'g',
                      amountKobo: 1000000,
                      allowExtra: true,
                      lateFeeKobo: 20000,
                      period: ContributionPeriod(
                        number: 1,
                        opensOn: DateTime(2026, 10, 4),
                        dueDate: DateTime(2026, 10, 10),
                      ),
                      today: DateTime(2026, 10, 11),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount paid (NGN)'),
        '9999',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Transfer reference'),
        'bank-reference',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(repo.submissions, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount paid (NGN)'),
        '15000.25',
      );
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(repo.tracker.contributions.single.amountKobo, 1500025);
    },
  );
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('landing adapts at width $width with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAjoTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: const LandingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
