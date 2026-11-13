import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/notifications_view.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_home_customer_calendar_section.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_offer_slider_section.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_renewal_status_banner.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_upcoming_plan_section.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_marketing_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_qb_marketplace_section.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_marketplace_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/services/plan_schedule_realtime_service.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_notification_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/animated_notification_bell.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_marketing_video_section.dart';
import 'package:quickboom_crm_customer/roles/customer/views/marketing_video_introduction_screen.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_marketing_video_viewmodel.dart';

class CustomerHomeView extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOpenDrawer;

  const CustomerHomeView({super.key, this.onNavigateToTab, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionManagerProvider);
    // Keep real-time WebSocket service active
    ref.watch(planScheduleRealtimeServiceProvider);

    // Listen for eligible unseen introduction marketing video.
    // Opens full-screen MarketingVideoIntroductionScreen instead of a dialog
    // so the video fills the entire display.
    ref.listen(customerIntroductionVideoProvider, (prev, next) {
      next.whenData((video) {
        if (video != null && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              MarketingVideoIntroductionScreen.push(
                context,
                video: video,
                // onDone is a no-op — the screen pops itself and the customer
                // dashboard (already mounted) is revealed automatically.
                onDone: () {},
              );
            }
          });
        }
      });
    });
    if (!perms.customerCan('CUSTOMER_HOME', 'VIEW')) {
      return const PermissionGuardedView(
        moduleKey: 'CUSTOMER_HOME',
        moduleTitle: 'Home Dashboard',
        child: SizedBox.shrink(),
      );
    }

    final canViewMarketing = perms.customerCan('CUSTOMER_MARKETING', 'VIEW');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/app_logo.png', width: 32, height: 32, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QB Suite Customer',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'CUSTOMER WORKSPACE',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Animated bell — only this widget rebuilds per animation frame.
          if (perms.customerCan('CUSTOMER_NOTIFICATIONS', 'VIEW'))
            AnimatedNotificationBell(
              onPressed: () {
                // Refresh notification state when the user opens the screen.
                ref
                    .read(employeeNotificationProvider.notifier)
                    .loadNotifications();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsView()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(loginStateProvider.notifier).refreshCustomerPermissions();
          ref.invalidate(currentCustomerIdProvider);
          ref.invalidate(customerHomeBannersProvider);
          ref.invalidate(customerMarketplaceToolsProvider);
          ref.invalidate(customerMarketingVideosProvider);
          ref.invalidate(customerIntroductionVideoProvider);
          final now = DateTime.now();
          ref
              .read(customerCalendarSelectedDateProvider.notifier)
              .setDate(DateTime(now.year, now.month, now.day));
          await refreshAllCustomerSubscriptionData(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Upcoming Plan Section (renders only when customer has a future subscription)
              const CustomerUpcomingPlanSection(),

              // 1. Dynamic Installment Renewal / Buffer Expiry Banner
              CustomerRenewalStatusBanner(onNavigateToPlans: onNavigateToTab),

              // 2. EXISTING MAIN PROMOTIONAL BANNER
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isTablet = width >= 550;
                  final bannerHeight = isTablet
                      ? (width / 2.3).clamp(240.0, 380.0)
                      : 156.0;
                  return CustomerOfferSliderSection(
                    onNavigateToTab: onNavigateToTab,
                    height: bannerHeight,
                  );
                },
              ),

              const SizedBox(height: 16),


              // 4. Customer Calendar Section (with Date Strip, Activity Filters, and Filtered Activity Cards)
              if (perms.customerCan('CUSTOMER_CALENDAR', 'VIEW'))
                const CustomerHomeCustomerCalendarSection(),

              const SizedBox(height: 18),

              // 5. QB Marketplace Section
              if (canViewMarketing)
                CustomerQbMarketplaceSection(onNavigateToTab: onNavigateToTab),

              const SizedBox(height: 18),

              // 6. Dynamic Marketing Video Section (collapses to SizedBox.shrink() when empty)
              if (canViewMarketing)
                CustomerMarketingVideoSection(onNavigateToTab: onNavigateToTab),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
