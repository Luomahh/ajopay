import '../../core/errors/result.dart';
import '../entities/contribution.dart';

abstract class ContributionRepository {
  Future<Result<ContributionTracker>> getTracker(String groupId);
  Future<Result<ContributionTracker>> submit({
    required String groupId,
    required int period,
    required int amountKobo,
    required String reference,
    required DateTime paidOn,
    required int expectedVersion,
  });
  Future<Result<ContributionTracker>> review({
    required String groupId,
    required int period,
    required String userId,
    required int version,
    required bool confirm,
    required String note,
  });
}
