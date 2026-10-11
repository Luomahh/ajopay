import 'package:flutter/foundation.dart';
import '../features/profile/profile_screen.dart';
import '../features/landing/landing_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/groups/create_group.dart';
import '../features/groups/join_group.dart';
import '../features/groups/group_detail.dart';
import '../features/contributions/contribution_screen.dart';
import '../features/chat/group_chat_screen.dart';
import '../features/payouts/payout_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh();
  // Refresh redirects without recreating the router or adding a second auth stream.
  ref.listen(sessionUserIdProvider, (_, _) => refresh.refresh());

  final router = GoRouter(
    initialLocation: kIsWeb ? '/' : '/sign-in',
    refreshListenable: refresh,
    redirect: (context, state) {
      final userId = ref.read(sessionUserIdProvider);
      final isOnAuthRoute =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';
      if (userId == null && !isOnAuthRoute && state.matchedLocation != '/') {
        return '/sign-in';
      }
      if (userId != null && isOnAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/groups/join',
        builder: (context, state) => const JoinGroupScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/groups/new',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:id/contributions',
        builder: (context, state) =>
            ContributionScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/groups/:id/payouts',
        builder: (context, state) =>
            PayoutScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/groups/:id/chat',
        builder: (context, state) =>
            GroupChatScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) =>
            GroupDetailScreen(groupId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
