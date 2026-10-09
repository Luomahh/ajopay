import 'package:ajopay/domain/entities/contribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open and overdue boundaries include all seven days', () {
    final p = ContributionPeriod(
      number: 1,
      opensOn: DateTime(2026, 10, 5),
      dueDate: DateTime(2026, 10, 11),
    );
    ContributionTracker at(int day) => ContributionTracker(
      today: DateTime(2026, 10, day),
      periods: [p],
      contributions: [],
      history: [],
    );
    expect(at(4).status(p, 'member'), 'Upcoming');
    expect(at(5).status(p, 'member'), 'Not submitted');
    expect(at(11).status(p, 'member'), 'Not submitted');
    expect(at(12).status(p, 'member'), 'Overdue');
  });
  test('pending and returned money are excluded from confirmed total', () {
    final t = ContributionTracker(
      today: DateTime(2026, 10, 9),
      periods: [],
      history: [],
      contributions: [
        for (final status in ['pending', 'confirmed', 'rejected'])
          Contribution(
            userId: status,
            period: 1,
            amountKobo: 500000,
            reference: status,
            paidOn: DateTime(2026, 10, 9),
            status: status,
            version: 1,
          ),
      ],
    );
    expect(t.confirmedKobo(1), 500000);
    expect(t.confirmedKobo(2), 0);
  });
}
