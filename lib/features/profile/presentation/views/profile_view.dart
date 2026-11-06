import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../../routes/route_names.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authViewModelProvider).asData?.value;
    return Scaffold(
      appBar: AppAppBar(
        title: 'Profile',
        onBack: () => context.goNamed(RouteNames.dashboard),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(session?.email ?? ''),
            Text(session?.role ?? ''),
            const SizedBox(height: 16),
            AppButton(
              label: 'Sign out',
              onPressed: () =>
                  ref.read(authViewModelProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
