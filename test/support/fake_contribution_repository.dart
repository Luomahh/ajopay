import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:ajopay/domain/repositories/contribution_repository.dart';

class FakeContributionRepository implements ContributionRepository {
  FakeContributionRepository(this.tracker, {this.userId = 'member'});
  ContributionTracker tracker;
  String userId;
  Failure? failure;
  int submissions = 0, reviews = 0;
  @override
  Future<Result<ContributionTracker>> getTracker(String groupId) async =>
      failure == null ? Result.success(tracker) : Result.failure(failure!);
  void update(Contribution c) {
    tracker = ContributionTracker(
      today: tracker.today,
      periods: tracker.periods,
      contributions: [
        ...tracker.contributions.where(
          (x) => x.period != c.period || x.userId != c.userId,
        ),
        c,
      ],
      history: [c, ...tracker.history],
    );
  }

  @override
  Future<Result<ContributionTracker>> submit({
    required String groupId,
    required int period,
    required int amountKobo,
    required String reference,
    required DateTime paidOn,
    required int expectedVersion,
  }) async {
    submissions++;
    if (failure != null) return Result.failure(failure!);
    update(
      Contribution(
        userId: userId,
        period: period,
        amountKobo: amountKobo,
        reference: reference,
        paidOn: paidOn,
        status: 'pending',
        version: expectedVersion + 1,
      ),
    );
    return Result.success(tracker);
  }

  @override
  Future<Result<ContributionTracker>> review({
    required String groupId,
    required int period,
    required String userId,
    required int version,
    required bool confirm,
    required String note,
  }) async {
    reviews++;
    if (failure != null) return Result.failure(failure!);
    final c = tracker.payment(period, userId)!;
    update(
      Contribution(
        userId: userId,
        period: period,
        amountKobo: c.amountKobo,
        reference: c.reference,
        paidOn: c.paidOn,
        status: confirm ? 'confirmed' : 'rejected',
        version: version,
        note: note.isEmpty ? null : note,
      ),
    );
    return Result.success(tracker);
  }
}
