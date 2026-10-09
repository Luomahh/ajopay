import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amount input preserves kobo exactly', () {
    expect(parseNairaToKobo('20000.50'), 2000050);
    expect(parseNairaToKobo('0.29'), 29);
    expect(parseNairaToKobo(' 120.1 '), 12010);
    expect(formatNaira(2000050), 'NGN 20,000.50');
  });

  test('ambiguous and excessive precision amounts are rejected', () {
    for (final value in [
      '',
      '-1',
      '1e6',
      '1.001',
      '20,000',
      'NaN',
      '10000000',
    ]) {
      expect(parseNairaToKobo(value), isNull, reason: value);
    }
  });

  test('ten contributions produce the scheduled pot without profit', () {
    final draft = GroupDraft(
      name: 'Friends',
      contributionKobo: 2000000,
      memberLimit: 10,
      firstPayoutDate: DateTime(2026, 10, 1),
    );
    expect(draft.scheduledPotKobo, 20000000);
    expect(draft.validate(DateTime(2026, 9, 24)), isNull);
    expect(draft.validate(DateTime(2026, 10, 1)), isNotNull);
  });

  test('draft validation rejects invalid names, capacity, and amounts', () {
    for (final draft in [
      GroupDraft(
        name: 'x',
        contributionKobo: 100,
        memberLimit: 2,
        firstPayoutDate: DateTime(2027),
      ),
      GroupDraft(
        name: 'Friends',
        contributionKobo: 99,
        memberLimit: 2,
        firstPayoutDate: DateTime(2027),
      ),
      GroupDraft(
        name: 'Friends',
        contributionKobo: 100,
        memberLimit: 1,
        firstPayoutDate: DateTime(2027),
      ),
      GroupDraft(
        name: 'Friends',
        contributionKobo: 100,
        memberLimit: 51,
        firstPayoutDate: DateTime(2027),
      ),
    ]) {
      expect(draft.validate(DateTime(2026)), isNotNull);
    }
  });
}
