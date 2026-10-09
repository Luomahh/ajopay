import '../../core/errors/result.dart';
import '../entities/savings_group.dart';
import '../entities/group_details.dart';

abstract class GroupRepository {
  Future<Result<GroupDetails>> getDetails(String id);
  Future<Result<GroupDetails>> prepareOrder(String id);
  Future<Result<GroupDetails>> acceptTerms(String id, int version);
  Future<Result<GroupDetails>> activate(String id, int version);
  Future<Result<List<SavingsGroup>>> listGroups();
  Future<Result<SavingsGroup>> joinGroup(String inviteCode);

  /// The server atomically creates the draft and its owner membership.
  /// Reusing [requestId] must return the same group without duplicates.
  Future<Result<SavingsGroup>> createGroup(GroupDraft draft, String requestId);
}
