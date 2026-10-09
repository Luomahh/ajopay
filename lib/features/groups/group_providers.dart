import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/group_details.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/savings_group.dart';
import '../../domain/repositories/group_repository.dart';
import '../auth/application/auth_providers.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(ref.watch(supabaseClientProvider));
});

final groupsProvider = FutureProvider.autoDispose<Result<List<SavingsGroup>>>((
  ref,
) {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return const Result.success([]);
  return ref.watch(groupRepositoryProvider).listGroups();
});

final groupDetailsProvider = FutureProvider.autoDispose
    .family<Result<GroupDetails>, String>((ref, id) {
      final userId = ref.watch(sessionUserIdProvider);
      if (userId == null) {
        return const Result.failure(PermissionFailure('Please sign in.'));
      }
      return ref.watch(groupRepositoryProvider).getDetails(id);
    });
