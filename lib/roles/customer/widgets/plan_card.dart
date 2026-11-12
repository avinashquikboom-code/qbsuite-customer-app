import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'plan_feature_item.dart';

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final SubscriptionBillingCycle billingCycle;
  final bool isCurrentPlan;
  final bool isSelected;
  final bool isExpired;
  final bool isPending;
  final bool isUpcoming;
  final VoidCallback onSelectPlan;
  final VoidCallback? onCardTap;

  const PlanCard({
    super.key,
    required this.plan,
    required this.billingCycle,
    required this.isCurrentPlan,
    this.isSelected = false,
    this.isExpired = false,
    this.isPending = false,
    this.isUpcoming = false,
    required this.onSelectPlan,
    this.onCardTap,
  });

  String _formatPrice(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;

    final lastThree = str.substring(str.length - 3);
    var remaining = str.substring(0, str.length - 3);
    final chunks = <String>[];
    while (remaining.length > 2) {
      chunks.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      chunks.insert(0, remaining);
    }
    return '${chunks.join(',')},$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final isYearly = billingCycle == SubscriptionBillingCycle.yearly;
    final price = plan.priceFor(billingCycle);
    final bool isHighlighted =
        isSelected || isCurrentPlan || plan.isRecommended;

    return GestureDetector(
      onTap: onCardTap ?? onSelectPlan,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? AppColors.primary : AppColors.borderLight,
            width: isHighlighted ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isHighlighted ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge (MOST POPULAR / CURRENT PLAN)
            if (plan.isRecommended || isCurrentPlan) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCurrentPlan
                        ? (isPending
                              ? [AppColors.warning, AppColors.orange]
                              : (isUpcoming
                                    ? [AppColors.sky, AppColors.purple]
                                    : [AppColors.primaryDark, AppColors.primary]))
                        : [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCurrentPlan
                          ? (isPending
                                ? Remix.time_fill
                                : (isUpcoming
                                      ? Remix.calendar_event_fill
                                      : Remix.shield_check_fill))
                          : Remix.fire_fill,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isCurrentPlan
                            ? (isPending
                                  ? 'YOUR PENDING PLAN'
                                  : (isUpcoming
                                        ? 'YOUR UPCOMING PLAN'
                                        : 'YOUR CURRENT ACTIVE PLAN'))
                            : 'MOST POPULAR',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package Name & Subtitle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (plan.subtitle != null &&
                                plan.subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                plan.subtitle!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isYearly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Save 20%',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Price Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          '₹${_formatPrice(price)}',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        billingCycle.priceSuffix,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Yearly Discount Applied Subtitle
                  if (isYearly) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Remix.checkbox_circle_fill,
                          size: 13,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '20% off applied — billed yearly',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 14),

                  // Features Header
                  Text(
                    'PACKAGE INCLUDES',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Features List
                  ...plan.features.map(
                    (feature) => PlanFeatureItem(
                      text: feature,
                      isHighlighted: isHighlighted,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Purchase Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isHighlighted
                        ? ElevatedButton(
                            onPressed: onSelectPlan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentPlan && isPending
                                  ? AppColors.warning
                                  : AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    isCurrentPlan
                                        ? (isPending
                                              ? 'Pending Approval'
                                              : (isUpcoming
                                                    ? 'Upcoming Plan'
                                                    : (isExpired
                                                          ? 'Renew Subscription'
                                                          : 'Current Plan')))
                                        : 'Purchase Now',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Remix.arrow_right_line, size: 16),
                              ],
                            ),
                          )
                        : OutlinedButton(
                            onPressed: onSelectPlan,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Purchase Now',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Remix.arrow_right_line, size: 14),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
