import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/payout.dart';
import '../../domain/entities/savings_group.dart';
import '../../domain/repositories/payout_repository.dart';

class PayoutRepositoryImpl implements PayoutRepository {
  PayoutRepositoryImpl(
    this.client, {
    this.timeout = const Duration(seconds: 15),
  });
  final SupabaseClient client;
  final Duration timeout;
  Future<Result<PayoutTracker>> request(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await client
          .rpc(function, params: params)
          .timeout(timeout);
      return Result.success(
        PayoutTracker.fromJson(Map<String, dynamic>.from(result as Map)),
      );
    } on TimeoutException {
      return const Result.failure(
        NetworkFailure(
          'Request timed out. Refresh or retry this record; do not send the money again.',
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return const Result.failure(
          PermissionFailure(
            'Only the leader can record payouts, and only the recipient can confirm receipt.',
          ),
        );
      }
      if (e.code == '22023') {
        return Result.failure(ValidationFailure(e.message));
      }
      if (e.code == '23505') {
        return const Result.failure(
          ValidationFailure(
            'This payout reference is already used. Check the transfer and refresh before trying again.',
          ),
        );
      }
      return const Result.failure(
        ServerFailure(
          'Payout tracking is unavailable. Please refresh and try again.',
        ),
      );
    } catch (_) {
      return const Result.failure(
        NetworkFailure(
          'Could not reach payout tracking. Check your connection and retry.',
        ),
      );
    }
  }

  @override
  Future<Result<PayoutTracker>> getTracker(String groupId) =>
      request('get_payout_tracker', {'p_group_id': groupId});
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
  }) => request('record_payout', {
    'p_group_id': groupId,
    'p_slot': slot,
    'p_recipient_id': recipientId,
    'p_amount_kobo': amountKobo,
    'p_reference': reference.trim(),
    'p_paid_on': dateOnly(paidOn),
    'p_expected_version': expectedVersion,
    'p_note': note.trim(),
  });
  @override
  Future<Result<PayoutTracker>> acknowledge({
    required String groupId,
    required int slot,
    required int version,
    required bool received,
    required String note,
  }) => request('acknowledge_payout', {
    'p_group_id': groupId,
    'p_slot': slot,
    'p_version': version,
    'p_received': received,
    'p_note': note.trim(),
  });
}
