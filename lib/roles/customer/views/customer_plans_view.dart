import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/billing_cycle_toggle.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/checkout_bottom_sheet.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/current_plan_card.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/plan_card.dart';
import 'package:quickboom_crm_customer/roles/customer/views/custom_plan_builder_view.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';

class CustomerPlansView extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOpenDrawer;

  const CustomerPlansView({super.key, this.onNavigateToTab, this.onOpenDrawer});

  @override
  ConsumerState<CustomerPlansView> createState() => _CustomerPlansViewState();
}

class _CustomerPlansViewState extends ConsumerState<CustomerPlansView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        refreshCustomerPlansData(ref);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      refreshCustomerPlansData(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    final canViewPlans = perms.customerCan('CUSTOMER_PLANS', 'VIEW');

    if (!canViewPlans) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: Navigator.canPop(context),
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Remix.arrow_left_line, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            'Subscription Plans',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
              tooltip: 'Open Menu',
              onPressed:
                  widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Remix.lock_line,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to view Subscription Plans. Please contact your administrator if you need access.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedCycle = ref.watch(selectedBillingCycleProvider);
    final selectedPlanCode = ref.watch(selectedPlanCodeProvider);
    final plansAsync = ref.watch(plansProvider);
    final subAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Subscription Plans',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.menu_line, color: AppColors.textPrimary),
            tooltip: 'Open Menu',
            onPressed:
                widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await refreshCustomerPlansData(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Current Active Plan Banner
              subAsync.when(
                data: (sub) => CurrentPlanCard(
                  subscription: sub,
                  onManagePlan: () {},
                  onRenewPlan: () {
                    final plans = plansAsync.asData?.value ?? [];
                    if (plans.isEmpty) return;
                    final matchedPlan = plans.firstWhere(
                      (p) => p.id == sub?.planId || p.code == sub?.planCode,
                      orElse: () => plans.first,
                    );
                    CheckoutBottomSheet.show(
                      context: context,
                      plan: matchedPlan,
                      cycle: sub?.billingCycle ?? selectedCycle,
                      onOrderSuccess: (newOrder) {
                        widget.onNavigateToTab?.call(3); // Go to orders tab
                      },
                    );
                  },
                  onViewOrders: () => widget.onNavigateToTab?.call(3),
                ),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),

              // 2. Section Header
              Text(
                'AVAILABLE PLANS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a curated plan that fits your business.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Custom Plan / Build Your Own Plan Card (Positioned at red line)
              _buildCustomPlanCard(context),

              const SizedBox(height: 16),

              // 3. Billing Cycle Selector (Monthly | Yearly)
              plansAsync.when(
                skipLoadingOnReload: true,
                data: (plans) {
                  double maxSavings = 0;
                  for (final p in plans) {
                    if (p.yearlySavingsPercentage > maxSavings) {
                      maxSavings = p.yearlySavingsPercentage;
                    }
                  }

                  return BillingCycleToggle(
                    selectedCycle: selectedCycle,
                    maxSavingsPercentage: maxSavings > 0 ? maxSavings : 16.0,
                    onCycleChanged: (cycle) {
                      ref
                          .read(selectedBillingCycleProvider.notifier)
                          .select(cycle);
                    },
                  );
                },
                loading: () => BillingCycleToggle(
                  selectedCycle: selectedCycle,
                  onCycleChanged: (cycle) {
                    ref
                        .read(selectedBillingCycleProvider.notifier)
                        .select(cycle);
                  },
                ),
                error: (err, stack) => BillingCycleToggle(
                  selectedCycle: selectedCycle,
                  onCycleChanged: (cycle) {
                    ref
                        .read(selectedBillingCycleProvider.notifier)
                        .select(cycle);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 4. Plans List
              plansAsync.when(
                skipLoadingOnReload: true,
                data: (plans) {
                  final uiPlanIds = plans.map((p) => p.id).join(', ');
                  debugPrint(
                    '[PLAN_MOBILE]\nUI planIds: ${uiPlanIds.isNotEmpty ? uiPlanIds : 'NONE'}',
                  );
                  debugPrint(
                    '[PLAN_UI]\nPlans received by widget: ${plans.length}',
                  );
                  for (final p in plans) {
                    debugPrint(
                      '[PLAN_UI]\nPlan ID: ${p.id}\nPlan name: ${p.name}\nMonthly price: ${p.monthlyPrice}\nYearly price: ${p.yearlyPrice}',
                    );
                  }
                  if (plans.isEmpty) {
                    return _buildEmptyState();
                  }

                  final currentSub = subAsync.asData?.value;
                  debugPrint(
                    '[PLAN_UI]\nPlans displayed count: ${plans.length}',
                  );

                  // If selectedPlanCode is not in plans list, fall back to first plan
                  final effectiveSelectedCode =
                      plans.any((p) => p.code == selectedPlanCode)
                      ? selectedPlanCode
                      : (plans
                            .firstWhere(
                              (p) => p.isRecommended,
                              orElse: () => plans.first,
                            )
                            .code);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int index = 0; index < plans.length; index++) ...[
                        Builder(
                          builder: (context) {
                            final plan = plans[index];
                            final isCurrentPlan =
                                currentSub != null &&
                                (currentSub.planId == plan.id ||
                                    currentSub.planCode.trim().toUpperCase() ==
                                        plan.code.trim().toUpperCase());
                            final isSelected =
                                effectiveSelectedCode == plan.code;

                            return PlanCard(
                              plan: plan,
                              billingCycle: selectedCycle,
                              isCurrentPlan: isCurrentPlan,
                              isSelected: isSelected,
                              isExpired: currentSub?.isExpired ?? false,
                              isPending: currentSub?.isPending ?? false,
                              isUpcoming: currentSub?.isUpcoming ?? false,
                              onCardTap: () {
                                ref
                                    .read(selectedPlanCodeProvider.notifier)
                                    .select(plan.code);
                              },
                              onSelectPlan: () {
                                ref
                                    .read(selectedPlanCodeProvider.notifier)
                                    .select(plan.code);
                                CheckoutBottomSheet.show(
                                  context: context,
                                  plan: plan,
                                  cycle: selectedCycle,
                                  onOrderSuccess: (order) {
                                    widget.onNavigateToTab?.call(3); // Orders tab
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
                loading: () => _buildLoadingSkeleton(),
                error: (error, _) => _buildErrorState(ref),
              ),

              SizedBox(height: 96.0 + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPlanCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.sound_module_fill,
                  color: AppColors.primaryDark,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Build Your Own Plan',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customise your services & quantities',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),
          Text(
            'Select exact quantities of Reels, Posts, Stories, Influencer Promos, and Ads Management tailored to your goals.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomPlanBuilderView(),
                  ),
                );
              },
              icon: const Icon(Remix.add_line, size: 16, color: Colors.white),
              label: Text(
                'Create Custom Plan',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 320,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Remix.price_tag_3_line,
              size: 48,
              color: AppColors.textPlaceholder,
            ),
            const SizedBox(height: 12),
            Text(
              'No Plans Available',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check again later or contact support.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Remix.error_warning_line,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to Load Plans',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check your internet connection.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(plansProvider.notifier).refresh();
              },
              icon: const Icon(Remix.refresh_line, size: 16),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
