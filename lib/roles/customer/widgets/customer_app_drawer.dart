import 'package:quickboom_crm_customer/roles/customer/views/customer_settings_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/viewmodels.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_company_admin/roles/company_admin/views/calendar/admin_customer_calendar_view.dart';
import 'package:quickboom_crm_customer/roles/customer/views/views.dart';
import 'package:quickboom_crm_customer/roles/employee/views/notifications_view.dart';

/// Standardized Customer Drawer for QuikBoom Mobile CRM.
class CustomerAppDrawer extends ConsumerWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final int? currentTabIndex;

  const CustomerAppDrawer({
    super.key,
    this.onNavigateToTab,
    this.currentTabIndex,
  });

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Remix.logout_box_r_line,
              color: AppColors.error,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your customer workspace session?',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (Navigator.canPop(ctx)) {
                Navigator.pop(ctx); // Close dialog
              }
              if (Navigator.canPop(context)) {
                Navigator.pop(context); // Close drawer
              }
              debugPrint(
                '[AUTH_DEBUG] logoutReason: User clicked Customer Logout',
              );
              await ref.read(loginStateProvider.notifier).logout();
              ref.invalidate(currentCustomerIdProvider);
              ref.invalidate(currentCustomerNameProvider);
              ref.invalidate(currentCustomerStateProvider);
              ref.invalidate(customerCalendarSelectedDateProvider);
              ref.invalidate(socialMediaWorkProvider);
              ref.invalidate(workProjectsProvider);
              ref.invalidate(leadsProvider);
              ref.invalidate(leadStagesProvider);
              ref.invalidate(proposalsProvider);
              ref.invalidate(currentSubscriptionProvider);
              ref.invalidate(customerOrdersProvider);
              ref.invalidate(paymentsProvider);
              ref.invalidate(customerSelectedWorkFilterProvider);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToScreen(BuildContext context, Widget targetScreen) {
    Navigator.pop(context); // Close drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
  }

  void _selectTab(BuildContext context, int tabIndex) {
    Navigator.pop(context); // Close drawer
    if (onNavigateToTab != null && currentTabIndex != tabIndex) {
      onNavigateToTab!(tabIndex);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionManagerProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.84).clamp(270.0, 350.0);

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 1. Sidebar Header (Customer Profile & QuikBoom Branding)
              _buildDrawerHeader(context, ref),

              // 2. Navigation Items List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSectionHeader('WORKSPACE NAVIGATION'),
                    if (perms.customerCan('CUSTOMER_HOME', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.home_5_line,
                        title: 'Home Dashboard',
                        isSelected: currentTabIndex == 0,
                        onTap: () => _selectTab(context, 0),
                      ),
                    if (perms.customerCan('CUSTOMER_PLANS', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.price_tag_3_line,
                        title: 'Subscription Plans',
                        isSelected: currentTabIndex == 1,
                        onTap: () => _selectTab(context, 1),
                      ),
                    if (perms.customerCan('CUSTOMER_ORDERS', 'VIEW') ||
                        perms.customerCan('CUSTOMER_INVOICES', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.file_list_3_line,
                        title: 'Orders & Invoices',
                        isSelected: currentTabIndex == 3,
                        onTap: () => _selectTab(context, 3),
                      ),
                    if (perms.customerCan('CUSTOMER_PROFILE', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.user_3_line,
                        title: 'Account Details',
                        isSelected: currentTabIndex == 4,
                        onTap: () => _selectTab(context, 4),
                      ),
                    if (perms.customerCan('CUSTOMER_SSM', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.share_line,
                        title: 'SSM Account Access',
                        isSelected: false,
                        onTap: () => _navigateToScreen(
                          context,
                          const SocialMediaWorkHandlerView(),
                        ),
                      ),
                    if (perms.customerCan('CUSTOMER_CALENDAR', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.calendar_event_line,
                        title: 'Customer Calendar',
                        isSelected: false,
                        onTap: () {
                          final customerIdAsync = ref.read(
                            currentCustomerIdProvider,
                          );
                          final customerId =
                              customerIdAsync.asData?.value ??
                              customerIdAsync.value;
                          _navigateToScreen(
                            context,
                            AdminCustomerCalendarView(
                              initialDate: DateTime.now(),
                              isCustomerScope: true,
                              customerId: customerId,
                            ),
                          );
                        },
                      ),
                    if (perms.customerCan('CUSTOMER_NOTIFICATIONS', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.notification_3_line,
                        title: 'Notifications',
                        isSelected: false,
                        onTap: () => _navigateToScreen(
                          context,
                          const NotificationsView(),
                        ),
                      ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    _buildSectionHeader('SUPPORT & HELP'),
                    _buildDrawerItem(
                      icon: Remix.lock_line,
                      title: 'Settings',
                      isSelected: false,
                      onTap: () => _navigateToScreen(
                        context,
                        const CustomerSettingsView(),
                      ),
                    ),
                    if (perms.customerCan('CUSTOMER_SUPPORT', 'VIEW'))
                      _buildDrawerItem(
                        icon: Remix.customer_service_2_line,
                        title: 'Support & Help Desk',
                        isSelected: false,
                        onTap: () => _navigateToScreen(
                          context,
                          const CustomerSupportView(),
                        ),
                      ),
                  ],
                ),
              ),

              // 3. Logout Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: InkWell(
                  onTap: () => _handleLogout(context, ref),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Remix.logout_box_r_line,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Remix.arrow_right_s_line,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(customerProfileProvider);
    final customerNameAsync = ref.watch(currentCustomerNameProvider);
    final profile = profileAsync.asData?.value;

    final customerPersonName =
        (profile?.personFullName.isNotEmpty == true
                ? profile!.personFullName
                : (customerNameAsync.asData?.value ??
                      customerNameAsync.value ??
                      'Valued Customer'))
            .trim();

    String businessWithCode = profile?.businessWithCode.isNotEmpty == true
        ? profile!.businessWithCode
        : '';
    if (businessWithCode.isEmpty) {
      final biz =
          (ref.watch(currentCustomerBusinessProvider).asData?.value ?? '')
              .trim();
      final cId = (ref.watch(currentCustomerIdProvider).asData?.value ?? '')
          .trim();
      final code = cId.startsWith('CUST-')
          ? cId
          : (cId.isNotEmpty ? 'CUST-$cId' : '');
      if (biz.isNotEmpty &&
          code.isNotEmpty &&
          biz.toLowerCase() != customerPersonName.toLowerCase()) {
        businessWithCode = '$biz • $code';
      } else if (biz.isNotEmpty &&
          biz.toLowerCase() != customerPersonName.toLowerCase()) {
        businessWithCode = biz;
      } else if (code.isNotEmpty) {
        businessWithCode = code;
      }
    }

    final initials =
        profile?.personInitials ??
        profile?.initials ??
        (customerPersonName.isNotEmpty
            ? customerPersonName
                  .substring(0, customerPersonName.length.clamp(1, 2))
                  .toUpperCase()
            : 'CU');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/images/app_logo.png', width: 44, height: 44, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QB Suite Customer',
                      style: GoogleFonts.outfit(
                        fontSize: 19,
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
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerPersonName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (businessWithCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          businessWithCode,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Remix.arrow_right_s_line,
                  size: 16,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
