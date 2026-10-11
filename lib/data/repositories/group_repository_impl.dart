import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/savings_group.dart';
import '../../domain/entities/group_details.dart';
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl(
    this._client, {
    this.requestTimeout = const Duration(seconds: 15),
  });
  final Duration requestTimeout;
  final SupabaseClient _client;

  Future<Result<T>> _request<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action().timeout(requestTimeout));
    } on TimeoutException {
      return const Result.failure(
        NetworkFailure(
          'This is taking longer than expected. Check your connection and try again.',
        ),
      );
    } on PostgrestException catch (error) {
      if (['PGRST202', 'PGRST205', '42P01', '42703'].contains(error.code)) {
        return const Result.failure(
          ServerFailure(
            'Group setup is not ready yet. Please contact the group organizer and try again later.',
          ),
        );
      }
      if (error.code == 'PGRST301') {
        return const Result.failure(
          PermissionFailure('Please sign in again to access your groups.'),
        );
      }
      if (error.code == '42501') {
        return const Result.failure(
          PermissionFailure(
            'You do not have permission to perform this group action.',
          ),
        );
      }
      if (error.code == '22023') {
        return const Result.failure(
          ValidationFailure(
            'The group is not ready for this action. Refresh to check its members, dates, and agreements.',
          ),
        );
      }
      if (error.code == '23505') {
        return const Result.failure(
          ValidationFailure(
            'This draft request was already saved. Return to the dashboard '
            'and refresh to see it before creating another.',
          ),
        );
      }
      return const Result.failure(
        ServerFailure('Groups are unavailable right now. Please try again.'),
      );
    } catch (_) {
      return const Result.failure(
        ServerFailure('Could not load or save your group. Please try again.'),
      );
    }
  }

  @override
  Future<Result<List<SavingsGroup>>> listGroups() => _request(() async {
    final rows = await _client
        .from('savings_groups')
        .select(
          'id,created_by,name,contribution_kobo,member_limit,first_payout_date,status,savings_mode,frequency,end_date,invite_code,rules_version,payout_frequency,first_collection_date,late_fee_kobo',
        )
        .order('created_at', ascending: false);
    return rows.map(SavingsGroup.fromJson).toList();
  });

  @override
  Future<Result<SavingsGroup>> createGroup(GroupDraft draft, String requestId) {
    final validation = draft.validate(DateTime.now());
    if (validation != null) {
      return Future.value(Result.failure(ValidationFailure(validation)));
    }
    return _request(() async {
      final response = await _client.rpc(
        draft.rulesVersion >= 2
            ? 'create_savings_group_v3'
            : 'create_savings_group_v2',
        params: {
          'p_request_id': requestId,
          'p_name': draft.name.trim(),
          'p_contribution_kobo': draft.contributionKobo,
          'p_member_limit': draft.memberLimit,
          'p_first_payout_date': dateOnly(draft.firstPayoutDate),
          'p_savings_mode': draft.mode.name,
          'p_frequency': draft.frequency.name,
          if (draft.rulesVersion >= 2) ...{
            'p_payout_frequency':
                (draft.payoutFrequency ?? draft.frequency).name,
            'p_first_collection_date': dateOnly(
              draft.firstCollectionDate ?? draft.firstPayoutDate,
            ),
          },
          'p_end_date': draft.endDate == null ? null : dateOnly(draft.endDate!),
        },
      );
      return SavingsGroup.fromJson(Map<String, dynamic>.from(response as Map));
    });
  }

  @override
  Future<Result<SavingsGroup>> joinGroup(String inviteCode) =>
      _request(() async {
        final response = await _client.rpc(
          'join_savings_group',
          params: {'p_invite_code': inviteCode.trim().toLowerCase()},
        );
        return SavingsGroup.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
      }).then(
        (result) => result.when(
          success: (g) => Result.success(g),
          failure: (f) => Result.failure(
            f is ValidationFailure
                ? const ValidationFailure(
                    'This invite is invalid, or the group is full or already active.',
                  )
                : f,
          ),
        ),
      );
  Future<Result<GroupDetails>> _detailsRequest(
    String function,
    String id, [
    int? version,
  ]) => _request(() async {
    final response = await _client.rpc(
      function,
      params: {'p_group_id': id, 'p_terms_version': ?version},
    );
    return GroupDetails.fromJson(Map<String, dynamic>.from(response as Map));
  });
  @override
  Future<Result<GroupDetails>> getDetails(String id) =>
      _detailsRequest('get_group_details', id);
  @override
  Future<Result<GroupDetails>> prepareOrder(String id) =>
      _detailsRequest('prepare_group_order', id);
  @override
  Future<Result<GroupDetails>> acceptTerms(String id, int version) =>
      _detailsRequest('accept_group_terms', id, version);
  @override
  Future<Result<GroupDetails>> activate(String id, int version) =>
      _detailsRequest('activate_savings_group', id, version);
}
