import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../../../routes/route_names.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppAppBar(
      title: 'Notifications',
      onBack: () => context.goNamed(RouteNames.dashboard),
    ),
    body: const SafeArea(
      child: AppEmptyState(
        title: 'Notifications are not connected yet',
        message: 'This feature will be connected to the notification service in a later migration.',
      ),
    ),
  );
}
