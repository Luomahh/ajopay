import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/entities/savings_group.dart';
import '../../domain/repositories/contribution_repository.dart';

class ContributionRepositoryImpl implements ContributionRepository {
  ContributionRepositoryImpl(
    this.client, {
    this.timeout = const Duration(seconds: 15),
  });
  final SupabaseClient client;
  final Duration timeout;
  Future<Result<ContributionTracker>> request(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await client
          .rpc(function, params: params)
          .timeout(timeout);
      return Result.success(
        ContributionTracker.fromJson(
          Map<String, dynamic>.from(response as Map),
        ),
      );
    } on TimeoutException {
      return const Result.failure(
        NetworkFailure(
          'The request timed out. Refresh or retry; your payment will not be duplicated.',
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return const Result.failure(
          PermissionFailure(
            'Only your group leader can review payments. Members can record their own payments.',
          ),
        );
      }
      if (e.code == '23505') {
        return const Result.failure(
          ValidationFailure(
            'This payment reference is already used for another period. Check the reference before retrying.',
          ),
        );
      }
      if (e.code == '22023') {
        return const Result.failure(
          ValidationFailure(
            'Check the payment amount, date and period. If it was already submitted or reviewed, refresh to see its current status.',
          ),
        );
      }
      return const Result.failure(
        ServerFailure(
          'Contribution tracking is unavailable. Please refresh and try again.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        NetworkFailure(
          'Could not reach contribution tracking. Check your connection and try again.',
        ),
      );
    }
  }

  @override
  Future<Result<ContributionTracker>> getTracker(String groupId) =>
      request('get_contribution_tracker', {'p_group_id': groupId});
  @override
  Future<Result<ContributionTracker>> submit({
    required String groupId,
    required int period,
    required int amountKobo,
    required String reference,
    required DateTime paidOn,
    required int expectedVersion,
    String? receiptPath,
    String? paymentNote,
  }) => request('submit_contribution_v2', {
    'p_group_id': groupId,
    'p_period': period,
    'p_amount_kobo': amountKobo,
    'p_reference': reference.trim(),
    'p_paid_on': dateOnly(paidOn),
    'p_expected_version': expectedVersion,
    'p_receipt_path': receiptPath,
    'p_payment_note': paymentNote?.trim(),
  });
  @override
  Future<Result<ContributionTracker>> review({
    required String groupId,
    required int period,
    required String userId,
    required int version,
    required bool confirm,
    required String note,
  }) => request('review_contribution', {
    'p_group_id': groupId,
    'p_period': period,
    'p_user_id': userId,
    'p_version': version,
    'p_confirm': confirm,
    'p_note': note.trim(),
  });
}
