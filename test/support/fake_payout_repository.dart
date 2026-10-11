import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/domain/entities/payout.dart';
import 'package:ajopay/domain/repositories/payout_repository.dart';

Map<String, dynamic> payoutFixture({
  String status = 'ready',
  String recipient = 'member',
  int slot = 1,
  int version = 0,
  bool? canRecord,
  int shortfall = 0,
}) => {
  'slot': slot,
  'recipient_id': recipient,
  'recipient_name': recipient == 'owner' ? 'Ada' : 'Tunde',
  'due_on': '2026-10-10',
  'amount_kobo': 2000000,
  'expected_pool_kobo': 2000000,
  'confirmed_pool_kobo': 2000000 - shortfall,
  'shortfall_kobo': shortfall,
  'status': status,
  'can_record': canRecord ?? (status == 'ready' || status == 'disputed'),
  'version': version,
  'transfer_reference': version > 0 ? 'DEMO-TRANSFER' : null,
  'paid_on': version > 0 ? '2026-10-10' : null,
  'leader_note': null,
  'recipient_note': status == 'disputed' ? 'Not received' : null,
};
Map<String, dynamic> trackerFixture({
  String status = 'active',
  String mode = 'rotating',
  List<Map<String, dynamic>>? rows,
}) => {
  'group_name': 'Friends & family',
  'group_status': status,
  'owner_id': 'owner',
  'mode': mode,
  'today': '2026-10-10',
  'payouts': rows ?? [payoutFixture()],
  'history': <Map<String, dynamic>>[],
};

class FakePayoutRepository implements PayoutRepository {
  FakePayoutRepository([Map<String, dynamic>? fixture])
    : data = fixture ?? trackerFixture();
  Map<String, dynamic> data;
  Failure? failure;
  final records = <Map<String, dynamic>>[];
  final acknowledgements = <Map<String, dynamic>>[];
  @override
  Future<Result<PayoutTracker>> getTracker(String groupId) async =>
      Result.success(PayoutTracker.fromJson(data));
  @override
  Future<Result<PayoutTracker>> record({
    required String groupId,
    required int slot,
    required String recipientId,
    required int amountKobo,
    required String reference,
    required DateTime paidOn,
    required int expectedVersion,
    required String note,
  }) async {
    records.add({
      'group': groupId,
      'slot': slot,
      'recipient': recipientId,
      'amount': amountKobo,
      'reference': reference,
      'version': expectedVersion,
      'note': note,
    });
    if (failure != null) return Result.failure(failure!);
    final row = (data['payouts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (p) => p['slot'] == slot && p['recipient_id'] == recipientId,
        );
    row.addAll({
      'status': 'reported',
      'can_record': false,
      'version': expectedVersion + 1,
      'transfer_reference': reference,
      'paid_on': '2026-10-10',
      'leader_note': note,
    });
    return getTracker(groupId);
  }

  @override
  Future<Result<PayoutTracker>> acknowledge({
    required String groupId,
    required int slot,
    required int version,
    required bool received,
    required String note,
  }) async {
    acknowledgements.add({
      'slot': slot,
      'version': version,
      'received': received,
      'note': note,
    });
    if (failure != null) return Result.failure(failure!);
    final row = (data['payouts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['slot'] == slot);
    row.addAll({
      'status': received ? 'confirmed' : 'disputed',
      'can_record': !received,
      'recipient_note': note,
    });
    if (received &&
        (data['payouts'] as List).every((p) => p['status'] == 'confirmed'))
      data['group_status'] = 'completed';
    return getTracker(groupId);
  }
}
