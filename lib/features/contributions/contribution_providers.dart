import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/contribution.dart';
import '../../domain/repositories/contribution_repository.dart';
import '../../data/repositories/contribution_repository_impl.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';

final contributionRepositoryProvider = Provider<ContributionRepository>(
  (ref) => ContributionRepositoryImpl(ref.watch(supabaseClientProvider)),
);
final contributionTrackerProvider = FutureProvider.autoDispose
    .family<Result<ContributionTracker>, String>((ref, id) {
      if (ref.watch(sessionUserIdProvider) == null) {
        return const Result.failure(PermissionFailure('Please sign in.'));
      }
      return ref.watch(contributionRepositoryProvider).getTracker(id);
    });
