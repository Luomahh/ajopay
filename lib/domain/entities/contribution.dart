import 'savings_group.dart';

class ContributionPeriod {
  const ContributionPeriod({
    required this.number,
    required this.opensOn,
    required this.dueDate,
  });
  final int number;
  final DateTime opensOn, dueDate;
  factory ContributionPeriod.fromJson(Map<String, dynamic> j) =>
      ContributionPeriod(
        number: j['period_number'] as int,
        opensOn: DateTime.parse(j['opens_on'] as String),
        dueDate: DateTime.parse(j['due_date'] as String),
      );
  bool isOpen(DateTime today) => !opensOn.isAfter(today);
}

class Contribution {
  const Contribution({
    required this.userId,
    required this.period,
    required this.amountKobo,
    required this.reference,
    required this.paidOn,
    required this.status,
    required this.version,
    this.note,
    this.receiptPath,
    this.paymentNote,
  });
  final String userId, reference, status;
  final int period, amountKobo, version;
  final DateTime paidOn;
  final String? note, receiptPath, paymentNote;
  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
    userId: j['user_id'] as String,
    period: j['period_number'] as int,
    amountKobo: j['amount_kobo'] as int,
    reference: j['payment_reference'] as String,
    paidOn: DateTime.parse(j['paid_on'] as String),
    status: j['status'] as String,
    version: j['version'] as int,
    receiptPath: j['receipt_path'] as String?,
    paymentNote: j['payment_note'] as String?,
    note: j['review_note'] as String? ?? j['note'] as String?,
  );
  String get label => switch (status) {
    'pending' => 'Awaiting review',
    'confirmed' => 'Confirmed by leader',
    'rejected' => 'Needs correction',
    _ => status,
  };
}

class ContributionTracker {
  const ContributionTracker({
    required this.today,
    required this.periods,
    required this.contributions,
    required this.history,
  });
  final DateTime today;
  final List<ContributionPeriod> periods;
  final List<Contribution> contributions, history;
  factory ContributionTracker.fromJson(
    Map<String, dynamic> j,
  ) => ContributionTracker(
    today: DateTime.parse(j['today'] as String),
    periods: (j['periods'] as List)
        .map(
          (x) =>
              ContributionPeriod.fromJson(Map<String, dynamic>.from(x as Map)),
        )
        .toList(),
    contributions: (j['contributions'] as List)
        .map((x) => Contribution.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    history: (j['history'] as List)
        .map((x) => Contribution.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
  );
  Contribution? payment(int period, String userId) {
    for (final c in contributions) {
      if (c.period == period && c.userId == userId) return c;
    }
    return null;
  }

  int get defaultPeriod {
    for (final p in periods) {
      if (!p.dueDate.isBefore(today)) return p.number;
    }
    return periods.isEmpty ? 1 : periods.last.number;
  }

  String status(ContributionPeriod period, String userId) =>
      payment(period.number, userId)?.label ??
      (!period.isOpen(today)
          ? 'Upcoming'
          : period.dueDate.isBefore(today)
          ? 'Overdue'
          : 'Not submitted');
  int confirmedKobo(int period) => contributions
      .where((c) => c.period == period && c.status == 'confirmed')
      .fold(0, (sum, c) => sum + c.amountKobo);
  String windowLabel(ContributionPeriod p) =>
      '${dateOnly(p.opensOn)} – ${dateOnly(p.dueDate)}';
}
