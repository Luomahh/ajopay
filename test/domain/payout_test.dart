import 'package:ajopay/domain/entities/payout.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_payout_repository.dart';

void main() {
  test('only acknowledged payouts count as received money', () {
    final t = PayoutTracker.fromJson(
      trackerFixture(
        rows: [
          payoutFixture(status: 'reported', version: 1),
          payoutFixture(status: 'disputed', version: 2),
          payoutFixture(status: 'confirmed', version: 1),
        ],
      ),
    );
    expect(t.confirmedCount, 1);
    expect(t.confirmedKobo, 2000000);
    expect(t.payouts[1].awaitingRecipient, true);
    expect(t.payouts[2].awaitingRecipient, false);
  });
  test('public payout summary parses without private transfer data', () {
    final p = Payout.fromJson(
      payoutFixture(status: 'reported', version: 1)..addAll({
        'transfer_reference': null,
        'paid_on': null,
        'leader_note': null,
      }),
    );
    expect(p.reference, isNull);
    expect(p.paidOn, isNull);
    expect(p.label, 'Awaiting recipient');
  });
}
