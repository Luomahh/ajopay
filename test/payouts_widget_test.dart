import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/features/auth/application/auth_providers.dart';
import 'package:ajopay/features/payouts/payout_providers.dart';
import 'package:ajopay/features/payouts/payout_screen.dart';
import 'package:ajopay/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_payout_repository.dart';
import 'widget_test.dart' show FakeAuthRepository;

void main() {
  Future<FakePayoutRepository> launch(
    WidgetTester tester, {
    String user = 'owner',
    Map<String, dynamic>? fixture,
  }) async {
    final repo = FakePayoutRepository(fixture);
    final auth = FakeAuthRepository()..currentUserId = user;
    addTearDown(() => auth.changes.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          payoutRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: buildAjoTheme(),
          home: const PayoutScreen(groupId: 'group'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> tap(WidgetTester t, String label) async {
    await t.ensureVisible(find.text(label));
    await t.pumpAndSettle();
    await t.tap(find.text(label));
    await t.pumpAndSettle();
  }

  testWidgets(
    'leader records exact scheduled payout and retains form after failure',
    (tester) async {
      final repo = await launch(tester);
      await tap(tester, 'Record payout');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Payout transfer reference'),
        'bank-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note (optional)'),
        'Sent to your agreed account',
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      repo.failure = const NetworkFailure('Connection interrupted');
      await tap(tester, 'Save payout record');
      expect(find.text('Connection interrupted'), findsOneWidget);
      expect(find.text('bank-123'), findsOneWidget);
      repo.failure = null;
      await tap(tester, 'Save payout record');
      expect(repo.records[0], repo.records[1]);
      expect(repo.records.last['amount'], 2000000);
      expect(repo.records.last['recipient'], 'member');
      expect(find.text('Awaiting recipient'), findsOneWidget);
      expect(find.text('Record payout'), findsNothing);
    },
  );
  testWidgets('shortfall blocks payout and does not count as received money', (
    tester,
  ) async {
    final repo = await launch(
      tester,
      fixture: trackerFixture(
        rows: [payoutFixture(status: 'collecting', shortfall: 1000000)],
      ),
    );
    expect(find.text('Still to confirm: NGN 10,000.00'), findsOneWidget);
    expect(find.text('Record payout'), findsNothing);
    expect(
      find.text('NGN 0.00 confirmed received by recipients'),
      findsOneWidget,
    );
    expect(repo.records, isEmpty);
  });
  testWidgets('member cannot record leader payout', (tester) async {
    await launch(tester, user: 'member');
    expect(find.text('Ready for payout'), findsOneWidget);
    expect(find.text('Record payout'), findsNothing);
  });
  testWidgets(
    'recipient acknowledgement completes round only after explicit confirmation',
    (tester) async {
      final repo = await launch(
        tester,
        user: 'member',
        fixture: trackerFixture(
          rows: [payoutFixture(status: 'reported', version: 1)],
        ),
      );
      await tap(tester, 'I received this money');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm receipt'),
      );
      expect(button.onPressed, isNull);
      expect(repo.acknowledgements, isEmpty);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tap(tester, 'Confirm receipt');
      expect(repo.acknowledgements.single['version'], 1);
      expect(find.text('SAVINGS ROUND COMPLETED'), findsOneWidget);
      expect(
        find.text('NGN 20,000.00 confirmed received by recipients'),
        findsOneWidget,
      );
      expect(find.text('I received this money'), findsNothing);
    },
  );
  testWidgets('problem requires reason and passes reviewed version', (
    tester,
  ) async {
    final repo = await launch(
      tester,
      user: 'member',
      fixture: trackerFixture(
        rows: [payoutFixture(status: 'reported', version: 2)],
      ),
    );
    await tap(tester, 'Report a problem');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tap(tester, 'Send problem report');
    expect(find.text('Please describe the problem.'), findsOneWidget);
    expect(repo.acknowledgements, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What went wrong?'),
      'Amount has not arrived',
    );
    await tap(tester, 'Send problem report');
    expect(repo.acknowledgements.single['received'], false);
    expect(repo.acknowledgements.single['version'], 2);
    expect(find.text('Problem reported'), findsOneWidget);
    expect(find.text('I received this money'), findsOneWidget);
  });
  testWidgets(
    'leader cannot acknowledge someone else and sees correction action',
    (tester) async {
      await launch(
        tester,
        fixture: trackerFixture(
          rows: [payoutFixture(status: 'disputed', version: 1)],
        ),
      );
      expect(find.text('Correct payout record'), findsOneWidget);
      expect(find.text('I received this money'), findsNothing);
    },
  );
  testWidgets('target plan shows principal and completed payouts read-only', (
    tester,
  ) async {
    await launch(
      tester,
      user: 'member',
      fixture: trackerFixture(
        status: 'completed',
        mode: 'target',
        rows: [payoutFixture(slot: 0, status: 'confirmed', version: 1)],
      ),
    );
    expect(find.text('End-date savings payout'), findsOneWidget);
    expect(find.text('Record payout'), findsNothing);
    expect(find.text('Report a problem'), findsNothing);
  });
  testWidgets('record form fits a small screen with keyboard and long note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);
    await tap(tester, 'Record payout');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note (optional)'),
      'A long note ' * 40,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
