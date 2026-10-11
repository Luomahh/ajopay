class Payout {
  const Payout({
    required this.slot,
    required this.recipientId,
    required this.recipientName,
    required this.dueOn,
    required this.amountKobo,
    required this.expectedPoolKobo,
    required this.confirmedPoolKobo,
    required this.shortfallKobo,
    required this.status,
    required this.canRecord,
    required this.version,
    this.reference,
    this.paidOn,
    this.leaderNote,
    this.recipientNote,
  });
  final int slot,
      amountKobo,
      expectedPoolKobo,
      confirmedPoolKobo,
      shortfallKobo,
      version;
  final String recipientId, recipientName, status;
  final DateTime dueOn;
  final bool canRecord;
  final String? reference, leaderNote, recipientNote;
  final DateTime? paidOn;
  String get label => payoutStatusLabel(status);
  bool get awaitingRecipient => status == 'reported' || status == 'disputed';
  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
    slot: j['slot'] as int,
    recipientId: j['recipient_id'] as String,
    recipientName: j['recipient_name'] as String,
    dueOn: DateTime.parse(j['due_on'] as String),
    amountKobo: j['amount_kobo'] as int,
    expectedPoolKobo: j['expected_pool_kobo'] as int,
    confirmedPoolKobo: j['confirmed_pool_kobo'] as int,
    shortfallKobo: j['shortfall_kobo'] as int,
    status: j['status'] as String,
    canRecord: j['can_record'] as bool,
    version: j['version'] as int,
    reference: j['transfer_reference'] as String?,
    paidOn: j['paid_on'] == null
        ? null
        : DateTime.parse(j['paid_on'] as String),
    leaderNote: j['leader_note'] as String?,
    recipientNote: j['recipient_note'] as String?,
  );
}

String payoutStatusLabel(String status) => switch (status) {
  'collecting' => 'Contributions outstanding',
  'scheduled' => 'Waiting for payout date',
  'waiting_previous' => 'Earlier payout awaits confirmation',
  'ready' => 'Ready for payout',
  'reported' => 'Awaiting recipient',
  'disputed' => 'Problem reported',
  'confirmed' => 'Receipt confirmed',
  _ => status,
};

class PayoutEvent {
  const PayoutEvent({
    required this.slot,
    required this.recipientId,
    required this.status,
    required this.version,
    required this.amountKobo,
    required this.reference,
    required this.paidOn,
    required this.createdAt,
    this.leaderNote,
    this.recipientNote,
  });
  final int slot, version, amountKobo;
  final String recipientId, status, reference;
  final DateTime paidOn, createdAt;
  final String? leaderNote, recipientNote;
  factory PayoutEvent.fromJson(Map<String, dynamic> j) => PayoutEvent(
    slot: j['slot'] as int,
    recipientId: j['recipient_id'] as String,
    status: j['status'] as String,
    version: j['version'] as int,
    amountKobo: j['amount_kobo'] as int,
    reference: j['transfer_reference'] as String,
    paidOn: DateTime.parse(j['paid_on'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
    leaderNote: j['leader_note'] as String?,
    recipientNote: j['recipient_note'] as String?,
  );
}

class PayoutTracker {
  const PayoutTracker({
    required this.groupName,
    required this.groupStatus,
    required this.ownerId,
    required this.mode,
    required this.today,
    required this.payouts,
    required this.history,
  });
  final String groupName, groupStatus, ownerId, mode;
  final DateTime today;
  final List<Payout> payouts;
  final List<PayoutEvent> history;
  int get confirmedCount =>
      payouts.where((p) => p.status == 'confirmed').length;
  int get confirmedKobo => payouts
      .where((p) => p.status == 'confirmed')
      .fold(0, (sum, p) => sum + p.amountKobo);
  factory PayoutTracker.fromJson(Map<String, dynamic> j) => PayoutTracker(
    groupName: j['group_name'] as String,
    groupStatus: j['group_status'] as String,
    ownerId: j['owner_id'] as String,
    mode: j['mode'] as String,
    today: DateTime.parse(j['today'] as String),
    payouts: List.unmodifiable(
      (j['payouts'] as List).map(
        (e) => Payout.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    ),
    history: List.unmodifiable(
      (j['history'] as List).map(
        (e) => PayoutEvent.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    ),
  );
}
