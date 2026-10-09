import 'savings_group.dart';

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.role,
    this.position,
    this.acceptedVersion,
  });
  final String userId, name, role;
  final int? position, acceptedVersion;
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    userId: j['user_id'] as String,
    name: j['name'] as String,
    role: j['role'] as String,
    position: j['rotation_position'] as int?,
    acceptedVersion: j['accepted_terms_version'] as int?,
  );
}

class GroupPeriod {
  const GroupPeriod({
    required this.number,
    required this.date,
    this.recipientId,
  });
  final int number;
  final DateTime date;
  final String? recipientId;
  factory GroupPeriod.fromJson(Map<String, dynamic> j) => GroupPeriod(
    number: j['period_number'] as int,
    date: DateTime.parse(j['due_date'] as String),
    recipientId: j['recipient_id'] as String?,
  );
}

class GroupDetails {
  const GroupDetails({
    required this.group,
    required this.ownerId,
    required this.version,
    required this.orderPrepared,
    required this.members,
    required this.periods,
  });
  final SavingsGroup group;
  final String ownerId;
  final int version;
  final bool orderPrepared;
  final List<GroupMember> members;
  final List<GroupPeriod> periods;
  bool get full => members.length == group.memberLimit;
  bool get readyForAgreement =>
      full && (group.mode == SavingsMode.target || orderPrepared);
  int get agreedCount =>
      members.where((m) => m.acceptedVersion == version).length;
  bool get allAgreed => readyForAgreement && agreedCount == members.length;
  GroupMember? member(String? id) {
    for (final m in members) {
      if (m.userId == id) return m;
    }
    return null;
  }

  List<GroupPeriod> get schedule {
    if (periods.isNotEmpty) return periods;
    if (group.mode == SavingsMode.rotating && !orderPrepared) return const [];
    final count = group.mode == SavingsMode.rotating
        ? group.memberLimit
        : scheduledContributions(
            group.firstPayoutDate,
            group.endDate!,
            group.frequency,
          );
    return List.generate(count, (i) {
      String? recipient;
      if (group.mode == SavingsMode.rotating) {
        for (final m in members) {
          if (m.position == i + 1) recipient = m.userId;
        }
      }
      return GroupPeriod(
        number: i + 1,
        date: contributionDate(group.firstPayoutDate, group.frequency, i),
        recipientId: recipient,
      );
    });
  }

  factory GroupDetails.fromJson(Map<String, dynamic> j) {
    final g = Map<String, dynamic>.from(j['group'] as Map);
    return GroupDetails(
      group: SavingsGroup.fromJson(g),
      ownerId: g['created_by'] as String,
      version: g['terms_version'] as int,
      orderPrepared: g['order_prepared'] as bool,
      members: List.unmodifiable(
        (j['members'] as List).map(
          (x) => GroupMember.fromJson(Map<String, dynamic>.from(x as Map)),
        ),
      ),
      periods: List.unmodifiable(
        (j['periods'] as List).map(
          (x) => GroupPeriod.fromJson(Map<String, dynamic>.from(x as Map)),
        ),
      ),
    );
  }
}
