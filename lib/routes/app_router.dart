import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_widgets.dart';
import '../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../features/auth/presentation/views/login_view.dart';
import '../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../features/dashboard/presentation/views/dashboard_view.dart';
import '../features/notifications/presentation/views/notifications_view.dart';
import '../features/profile/presentation/views/profile_view.dart';
import 'route_names.dart';

// Keep the router stable across authentication transitions.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authViewModelProvider, (_, next) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, route) {
      final auth = ref.read(authViewModelProvider);
      final atLogin = route.matchedLocation == '/login';
      if (auth.isLoading) return null; // Gate below blocks protected content.
      final signedIn = auth.asData?.value != null;
      if (!signedIn && !atLogin) {
        return Uri(
          path: '/login',
          queryParameters: {'from': route.uri.toString()},
        ).toString();
      }
      if (signedIn && atLogin) {
        final from = route.uri.queryParameters['from'];
        final uri = from == null ? null : Uri.tryParse(from);
        return uri != null &&
                !uri.hasAuthority &&
                !uri.hasScheme &&
                from!.startsWith('/') &&
                uri.path != '/login'
            ? from
            : '/';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppAppBar(title: 'Page not found', onBack: () => context.go('/')),
      body: const AppEmptyState(title: 'Page not found'),
    ),
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (_, state) => const LoginView(),
      ),
      ShellRoute(
        builder: (_, state, child) => _SessionGate(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: RouteNames.dashboard,
            builder: (_, state) => const DashboardView(),
            routes: [
              GoRoute(
                path: 'features/:id',
                name: RouteNames.feature,
                builder: (_, state) =>
                    _FeatureView(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (_, state) => const ProfileView(),
          ),
          GoRoute(
            path: '/notifications',
            name: RouteNames.notifications,
            builder: (_, state) => const NotificationsView(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _SessionGate extends ConsumerWidget {
  const _SessionGate({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewModelProvider);
    if (auth.isLoading) return const Scaffold(body: AppLoader());
    if (auth.asData?.value == null) return const Scaffold(body: AppLoader());
    return child;
  }
}

class _FeatureView extends ConsumerWidget {
  const _FeatureView({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppAppBar(
      title: 'Feature',
      onBack: () => context.goNamed(RouteNames.dashboard),
    ),
    body: SafeArea(
      child: ref
          .watch(dashboardFeaturesProvider)
          .when(
            loading: () => const AppLoader(),
            error: (e, s) => AppErrorWidget(message: e.toString()),
            data: (items) {
              final matches = items.where((item) => item.id == id);
              return AppEmptyState(
                title: matches.isEmpty
                    ? 'Feature not found'
                    : matches.first.title,
                message: matches.isEmpty
                    ? null
                    : 'This feature is not connected yet.',
              );
            },
          ),
    ),
  );
}
