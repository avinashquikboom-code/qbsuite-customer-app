import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/providers/auth_provider.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/customer_app_drawer.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';
import 'customer_trending_view.dart';
import 'customer_account_view.dart';
import 'customer_home_view.dart';
import 'customer_orders_view.dart';
import 'customer_plans_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class CustomerDashboardView extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const CustomerDashboardView({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<CustomerDashboardView> createState() =>
      _CustomerDashboardViewState();
}

class _CustomerDashboardViewState extends ConsumerState<CustomerDashboardView>
    with WidgetsBindingObserver {
  late int _currentIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService.instance.requestAndroidNotificationPermission();
      // Providers must not be modified while the widget tree is building.
      if (PermissionManager.instance.currentState.permissions.isEmpty) {
        ref.read(permissionManagerProvider.notifier).setLoading(true);
      }
      _refreshCustomerPermissions();
      refreshAllCustomerSubscriptionData(ref, resetSelectedDate: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshAllCustomerSubscriptionData(ref, resetSelectedDate: false);
    }
  }

  Future<void> _refreshCustomerPermissions() async {
    try {
      await ref.read(loginStateProvider.notifier).refreshCustomerPermissions();
    } catch (e) {
      debugPrint('[CUSTOMER_RBAC] permission refresh failed: $e');
    }
  }

  void _navigateToTab(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
      if (index == 1) {
        refreshCustomerPlansData(ref);
      } else if (index == 0 || index == 4) {
        refreshAllCustomerSubscriptionData(ref);
      }
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    final tabs =
        <
          ({
            int index,
            String label,
            IconData icon,
            IconData active,
            Widget page,
          })
        >[
          if (perms.customerCan('CUSTOMER_HOME', 'VIEW'))
            (
              index: 0,
              label: 'Home',
              icon: Remix.home_5_line,
              active: Remix.home_5_fill,
              page: CustomerHomeView(
                onNavigateToTab: _navigateToTab,
                onOpenDrawer: _openDrawer,
              ),
            ),
          if (perms.customerCan('CUSTOMER_PLANS', 'VIEW'))
            (
              index: 1,
              label: 'Plans',
              icon: Remix.price_tag_3_line,
              active: Remix.price_tag_3_fill,
              page: CustomerPlansView(
                onNavigateToTab: _navigateToTab,
                onOpenDrawer: _openDrawer,
              ),
            ),
          if (perms.customerCan('CUSTOMER_TRENDING', 'VIEW'))
            (
              index: 2,
              label: 'Trending',
              icon: Remix.fire_line,
              active: Remix.fire_fill,
              page: const CustomerTrendingView(),
            ),
          if (perms.customerCan('CUSTOMER_ORDERS', 'VIEW') ||
              perms.customerCan('CUSTOMER_INVOICES', 'VIEW'))
            (
              index: 3,
              label: 'Orders',
              icon: Remix.file_list_3_line,
              active: Remix.file_list_3_fill,
              page: CustomerOrdersView(
                onNavigateToTab: _navigateToTab,
                onOpenDrawer: _openDrawer,
              ),
            ),
          if (perms.customerCan('CUSTOMER_PROFILE', 'VIEW'))
            (
              index: 4,
              label: 'Profile',
              icon: Remix.user_3_line,
              active: Remix.user_3_fill,
              page: CustomerAccountView(
                onNavigateToTab: _navigateToTab,
                onOpenDrawer: _openDrawer,
              ),
            ),
        ];

    final selected = tabs.where((t) => t.index == _currentIndex);
    final active = selected.isNotEmpty
        ? selected.first
        : (tabs.isNotEmpty ? tabs.first : null);

    if (active != null && active.index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = active.index;
          });
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.scaffoldBg,
        extendBody: false,
        drawer: CustomerAppDrawer(
          onNavigateToTab: _navigateToTab,
          currentTabIndex: _currentIndex,
        ),
        drawerEnableOpenDragGesture: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: !perms.isReady
              ? const SkeletonList(count: 4)
              : perms.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        perms.error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshCustomerPermissions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : active == null
              ? Center(
                  child: Text(
                    'No modules are available for this account.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : KeyedSubtree(key: ValueKey(active.index), child: active.page),
        ),
        bottomNavigationBar: tabs.isEmpty
            ? null
            : Material(
                color: Colors.white,
                elevation: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    child: SizedBox(
                      height: 62,
                      child: Row(
                        children: [
                          for (final tab in tabs)
                            _buildNavItem(
                              tab.index,
                              tab.label,
                              tab.icon,
                              tab.active,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
  ) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _navigateToTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
