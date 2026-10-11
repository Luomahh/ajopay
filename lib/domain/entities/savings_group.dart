enum SavingsMode { rotating, target }

enum SavingsFrequency { daily, weekly, monthly }

extension SavingsFrequencyLabel on SavingsFrequency {
  String get label => switch (this) {
    SavingsFrequency.daily => 'Daily',
    SavingsFrequency.weekly => 'Weekly',
    SavingsFrequency.monthly => 'Monthly',
  };
  String get interval => switch (this) {
    SavingsFrequency.daily => 'day',
    SavingsFrequency.weekly => 'week',
    SavingsFrequency.monthly => 'month',
  };
}

/// Calendar dates anchored to the original day; Jan 31 -> Feb 28 -> Mar 31.
DateTime contributionDate(
  DateTime first,
  SavingsFrequency frequency,
  int index,
) {
  if (frequency != SavingsFrequency.monthly) {
    return DateTime.utc(
      first.year,
      first.month,
      first.day + index * (frequency == SavingsFrequency.daily ? 1 : 7),
    );
  }
  final month = DateTime.utc(first.year, first.month + index);
  final last = DateTime.utc(month.year, month.month + 1, 0).day;
  return DateTime.utc(
    month.year,
    month.month,
    first.day > last ? last : first.day,
  );
}

int scheduledContributions(
  DateTime first,
  DateTime end,
  SavingsFrequency frequency,
) {
  final until = DateTime.utc(end.year, end.month, end.day);
  var count = 0;
  while (count < 3661 &&
      !contributionDate(first, frequency, count).isAfter(until)) {
    count++;
  }
  return count;
}

/// Draft terms for one monthly savings round. All amounts are NGN minor units.
class GroupDraft {
  const GroupDraft({
    required this.name,
    required this.contributionKobo,
    required this.memberLimit,
    required this.firstPayoutDate,
    this.mode = SavingsMode.rotating,
    this.frequency = SavingsFrequency.monthly,
    this.endDate,
    this.rulesVersion = 1,
    this.payoutFrequency,
    this.firstCollectionDate,
    this.lateFeeKobo = 0,
  });

  final String name;
  final int contributionKobo;
  final int memberLimit;
  final DateTime firstPayoutDate;
  final SavingsMode mode;
  final SavingsFrequency frequency;
  final DateTime? endDate;
  final int rulesVersion, lateFeeKobo;
  final SavingsFrequency? payoutFrequency;
  final DateTime? firstCollectionDate;
  bool get allowsExtra => rulesVersion >= 2 && mode == SavingsMode.target;
  DateTime get lastContributionDate => mode == SavingsMode.target
      ? endDate!
      : contributionDate(
          firstCollectionDate ?? firstPayoutDate,
          payoutFrequency ?? frequency,
          memberLimit - 1,
        );

  int get contributionCount => mode == SavingsMode.rotating
      ? (rulesVersion >= 2
            ? scheduledContributions(
                firstPayoutDate,
                lastContributionDate,
                frequency,
              )
            : memberLimit)
      : endDate == null
      ? 0
      : scheduledContributions(firstPayoutDate, endDate!, frequency);
  int get principalPerMemberKobo => contributionKobo * contributionCount;

  int get scheduledPotKobo => contributionKobo * memberLimit;

  String? validate(DateTime today) {
    if (name.trim().length < 3 || name.trim().length > 80) {
      return 'Use a group name between 3 and 80 characters.';
    }
    if (contributionKobo < 100 || contributionKobo > 100000000) {
      return 'Enter a contribution between NGN 1 and NGN 1,000,000.';
    }
    if (memberLimit < 2 || memberLimit > 50) {
      return 'Choose between 2 and 50 members, including yourself.';
    }
    final date = DateTime(today.year, today.month, today.day);
    if (firstPayoutDate.isBefore(date.add(const Duration(days: 1)))) {
      return 'Choose a first payout date after today.';
    }
    if (mode == SavingsMode.target &&
        (endDate == null ||
            !endDate!.isAfter(firstPayoutDate) ||
            endDate!.isAfter(
              DateTime(today.year + 2, today.month, today.day),
            ))) {
      return 'Choose an end date after the first contribution, within two years.';
    }
    if (rulesVersion >= 2 && mode == SavingsMode.rotating) {
      final payout = payoutFrequency ?? frequency;
      final first = firstCollectionDate ?? firstPayoutDate;
      if (first.isBefore(firstPayoutDate) ||
          first.isAfter(contributionDate(firstPayoutDate, payout, 1)) ||
          (frequency == SavingsFrequency.monthly &&
              payout != SavingsFrequency.monthly) ||
          (frequency == SavingsFrequency.weekly &&
              payout == SavingsFrequency.daily)) {
        return 'Choose a payout frequency no faster than contributions, and a first payout within one payout interval of the first contribution.';
      }
    }
    return null;
  }
}

/// Parses decimal input without rounding through floating point arithmetic.
int? parseNairaToKobo(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final naira = int.parse(parts.first);
  final kobo = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  return naira * 100 + kobo;
}

String formatNaira(int kobo) {
  final whole = (kobo ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return 'NGN $whole.${(kobo % 100).toString().padLeft(2, '0')}';
}

String dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class SavingsGroup {
  const SavingsGroup({
    required this.id,
    required this.name,
    required this.contributionKobo,
    required this.memberLimit,
    required this.firstPayoutDate,
    this.mode = SavingsMode.rotating,
    this.frequency = SavingsFrequency.monthly,
    this.endDate,
    this.rulesVersion = 1,
    this.payoutFrequency,
    this.firstCollectionDate,
    this.lateFeeKobo = 0,
    required this.status,
    this.inviteCode,
    this.ownerId,
  });

  final String id;
  final String name;
  final int contributionKobo;
  final int memberLimit;
  final DateTime firstPayoutDate;
  final SavingsMode mode;
  final SavingsFrequency frequency;
  final DateTime? endDate;
  final int rulesVersion, lateFeeKobo;
  final SavingsFrequency? payoutFrequency;
  final DateTime? firstCollectionDate;
  bool get allowsExtra => rulesVersion >= 2 && mode == SavingsMode.target;
  DateTime get lastContributionDate => mode == SavingsMode.target
      ? endDate!
      : contributionDate(
          firstCollectionDate ?? firstPayoutDate,
          payoutFrequency ?? frequency,
          memberLimit - 1,
        );

  final String status;
  final String? inviteCode;
  final String? ownerId;

  factory SavingsGroup.fromJson(Map<String, dynamic> json) => SavingsGroup(
    id: json['id'] as String,
    ownerId: json['created_by'] as String?,
    name: json['name'] as String,
    contributionKobo: json['contribution_kobo'] as int,
    memberLimit: json['member_limit'] as int,
    firstPayoutDate: DateTime.parse(json['first_payout_date'] as String),
    status: json['status'] as String,
    rulesVersion: json['rules_version'] as int? ?? 1,
    lateFeeKobo: json['late_fee_kobo'] as int? ?? 0,
    payoutFrequency: json['payout_frequency'] == null
        ? null
        : SavingsFrequency.values.byName(json['payout_frequency'] as String),
    firstCollectionDate: json['first_collection_date'] == null
        ? null
        : DateTime.parse(json['first_collection_date'] as String),
    mode: SavingsMode.values.byName(
      json['savings_mode'] as String? ?? 'rotating',
    ),
    frequency: SavingsFrequency.values.byName(
      json['frequency'] as String? ?? 'monthly',
    ),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
    inviteCode: json['invite_code'] as String?,
  );
}
