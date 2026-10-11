import '../../core/errors/result.dart';
import '../entities/payout.dart';

abstract class PayoutRepository {
  Future<Result<PayoutTracker>> getTracker(String groupId);
  Future<Result<PayoutTracker>> record({
    required String groupId,
    required int slot,
    required String recipientId,
    required int amountKobo,
    required String reference,
    required DateTime paidOn,
    required int expectedVersion,
    required String note,
  });
  Future<Result<PayoutTracker>> acknowledge({
    required String groupId,
    required int slot,
    required int version,
    required bool received,
    required String note,
  });
}
