import 'package:ajopay/core/errors/failure.dart';
import 'package:ajopay/core/errors/result.dart';
import 'package:ajopay/domain/entities/savings_group.dart';
import 'package:ajopay/domain/entities/group_details.dart';
import 'package:ajopay/domain/repositories/group_repository.dart';

class FakeGroupRepository implements GroupRepository {
  final groups = <SavingsGroup>[];
  final requests = <String>[];
  Failure? createFailure;
  Failure? listFailure;
  GroupDraft? lastDraft;

  GroupDetails? detail;
  Failure? detailFailure;
  Failure? actionFailure;
  final acceptedVersions = <int>[];
  final activatedVersions = <int>[];
  final joinedCodes = <String>[];
  @override
  Future<Result<GroupDetails>> getDetails(String id) async {
    if (detailFailure != null) return Result.failure(detailFailure!);
    return Result.success(
      detail ??
          GroupDetails(
            group: groups.firstWhere((g) => g.id == id),
            ownerId: 'owner',
            version: 1,
            orderPrepared: false,
            members: const [
              GroupMember(userId: 'owner', name: 'Leader', role: 'owner'),
            ],
            periods: const [],
          ),
    );
  }

  @override
  Future<Result<GroupDetails>> prepareOrder(String id) => getDetails(id);
  @override
  Future<Result<GroupDetails>> acceptTerms(String id, int version) async {
    acceptedVersions.add(version);
    if (actionFailure != null) return Result.failure(actionFailure!);
    final d = (await getDetails(id) as Success<GroupDetails>).value;
    detail = GroupDetails(
      group: d.group,
      ownerId: d.ownerId,
      version: d.version,
      orderPrepared: d.orderPrepared,
      members: [
        for (final m in d.members)
          GroupMember(
            userId: m.userId,
            name: m.name,
            role: m.role,
            position: m.position,
            acceptedVersion: m.userId == 'owner' ? version : m.acceptedVersion,
          ),
      ],
      periods: d.periods,
    );
    return Result.success(detail!);
  }

  @override
  Future<Result<GroupDetails>> activate(String id, int version) async {
    activatedVersions.add(version);
    if (actionFailure != null) return Result.failure(actionFailure!);
    final d = (await getDetails(id) as Success<GroupDetails>).value;
    final g = d.group;
    detail = GroupDetails(
      group: SavingsGroup(
        id: g.id,
        name: g.name,
        contributionKobo: g.contributionKobo,
        memberLimit: g.memberLimit,
        firstPayoutDate: g.firstPayoutDate,
        status: 'active',
        mode: g.mode,
        frequency: g.frequency,
        endDate: g.endDate,
      ),
      ownerId: d.ownerId,
      version: d.version,
      orderPrepared: d.orderPrepared,
      members: d.members,
      periods: d.schedule,
    );
    return Result.success(detail!);
  }

  @override
  Future<Result<List<SavingsGroup>>> listGroups() async => listFailure != null
      ? Result.failure(listFailure!)
      : Result.success(List.of(groups));

  @override
  Future<Result<SavingsGroup>> createGroup(
    GroupDraft draft,
    String requestId,
  ) async {
    requests.add(requestId);
    lastDraft = draft;
    if (createFailure != null) return Result.failure(createFailure!);
    final group = SavingsGroup(
      id: requestId,
      name: draft.name,
      contributionKobo: draft.contributionKobo,
      memberLimit: draft.memberLimit,
      firstPayoutDate: draft.firstPayoutDate,
      status: 'draft',
      mode: draft.mode,
      frequency: draft.frequency,
      endDate: draft.endDate,
      rulesVersion: draft.rulesVersion,
      payoutFrequency: draft.payoutFrequency,
      firstCollectionDate: draft.firstCollectionDate,
      lateFeeKobo: draft.lateFeeKobo,
      inviteCode: requestId,
    );
    groups.add(group);
    return Result.success(group);
  }

  @override
  Future<Result<SavingsGroup>> joinGroup(String inviteCode) async {
    joinedCodes.add(inviteCode);
    for (final g in groups) {
      if (g.inviteCode == inviteCode.trim().toLowerCase()) {
        return Result.success(g);
      }
    }
    return const Result.failure(ValidationFailure('Invalid invite'));
  }
}
