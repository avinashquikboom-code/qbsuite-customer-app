import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/icons/remix_icon.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../routes/route_names.dart';
import '../providers/dashboard_providers.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(dashboardFeaturesProvider);
    final query = ref.watch(dashboardQueryProvider).toLowerCase();
    return Scaffold(
      appBar: const AppAppBar(title: AppConfig.title),
      bottomNavigationBar: AppBottomNavigation(
        index: 0,
        onSelected: (index) {
          if (index == 1) context.goNamed(RouteNames.notifications);
          if (index == 2) context.goNamed(RouteNames.profile);
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardFeaturesProvider);
            await ref.read(dashboardFeaturesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppSearchBar(
                onChanged: ref.read(dashboardQueryProvider.notifier).update,
              ),
              const SizedBox(height: 16),
              features.when(
                loading: () => const AppLoader(),
                error: (e, s) => AppErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(dashboardFeaturesProvider),
                ),
                data: (items) {
                  final visible = items
                      .where((item) => item.title.toLowerCase().contains(query))
                      .toList();
                  if (visible.isEmpty) {
                    return const AppEmptyState(title: 'No matching features');
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: visible
                            .map(
                              (feature) => SizedBox(
                                width: width,
                                child: AppCard(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const RemixIcon(AppIcon.grid),
                                    title: Text(feature.title),
                                    trailing: const RemixIcon(AppIcon.next),
                                    onTap: () => context.goNamed(
                                      RouteNames.feature,
                                      pathParameters: {'id': feature.id},
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
