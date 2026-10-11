import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/result.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/payout.dart';
import '../../domain/repositories/payout_repository.dart';
import '../../data/repositories/payout_repository_impl.dart';
import '../../data/datasources/supabase_client_provider.dart';
import '../auth/application/auth_providers.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>(
  (ref) => PayoutRepositoryImpl(ref.watch(supabaseClientProvider)),
);
final payoutTrackerProvider = FutureProvider.autoDispose
    .family<Result<PayoutTracker>, String>((ref, id) {
      if (ref.watch(sessionUserIdProvider) == null) {
        return const Result.failure(PermissionFailure('Please sign in.'));
      }
      return ref.watch(payoutRepositoryProvider).getTracker(id);
    });
