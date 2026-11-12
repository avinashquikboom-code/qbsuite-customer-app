import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import '../models/lead_limit_model.dart';
import '../viewmodels/lead_limit_viewmodel.dart';

class LeadLimitCard extends ConsumerWidget {
  final EdgeInsetsGeometry margin;

  const LeadLimitCard({super.key, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitAsync = ref.watch(leadLimitProvider);

    if (limitAsync.hasError) {
      return _buildErrorCard(context, ref);
    }

    return limitAsync.when(
      data: (data) => _buildCard(context, ref, data),
      loading: () => _buildLoadingSkeleton(context),
      error: (error, stack) => _buildErrorCard(context, ref),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    EmployeeLeadLimitModel data,
  ) {
    final isDailyExhausted = data.daily.isExhausted;
    final isMonthlyExhausted = data.monthly.isExhausted;

    // Resolve designation dynamically from quota model or permission manager
    final perms = ref.watch(permissionManagerProvider);
    final String rawRole;
    if (data.roleName != null && data.roleName!.trim().isNotEmpty) {
      rawRole = data.roleName!.trim();
    } else if (perms.role != null && perms.role!.trim().isNotEmpty) {
      rawRole = perms.role!.trim();
    } else {
      rawRole = '';
    }
    final displayRole = rawRole.isNotEmpty
        ? '${rawRole.toUpperCase()}${data.isCustom ? ' • CUSTOM LIMIT' : ''}'
        : '';

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDailyExhausted || isMonthlyExhausted)
              ? AppColors.error.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.shield_user_line,
                  color: AppColors.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lead Generation Quota',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayRole.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        displayRole,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Remix.refresh_line, size: 16),
                  color: AppColors.textSecondary,
                  tooltip: 'Refresh Quota',
                  onPressed: () =>
                      ref.read(leadLimitProvider.notifier).fetchLimits(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── TWO SEPARATE CARDS — always side-by-side on ALL screen sizes ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPeriodCard(
                  context,
                  title: 'Today',
                  period: data.daily,
                  accentColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPeriodCard(
                  context,
                  title: 'This Month',
                  period: data.monthly,
                  accentColor: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),

          // Alert banner if limit reached
          if (isDailyExhausted || isMonthlyExhausted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Remix.error_warning_fill,
                    color: AppColors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isDailyExhausted
                          ? 'Daily lead generation limit reached.'
                          : 'Monthly lead generation limit reached.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a single period card (Today or This Month) with its own
  /// card decoration, accent colour, and progress bar.
  Widget _buildPeriodCard(
    BuildContext context, {
    required String title,
    required LeadLimitPeriod period,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    final isExhausted = period.isExhausted;
    final progress = period.limit > 0
        ? (period.used / period.limit).clamp(0.0, 1.0)
        : 0.0;

    final Color statusColor = isExhausted
        ? AppColors.error
        : (progress > 0.85 ? AppColors.warning : accentColor);

    return Container(
      // Width is controlled by Expanded in the parent Row — no fixed width.
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isExhausted
              ? AppColors.error.withValues(alpha: 0.25)
              : statusColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Keep the period title on its own line so it remains readable on
          // narrow phones, even when the remaining-count badge is long.
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            softWrap: true,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${period.remaining} left',
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 5),

          // Used / Limit count
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${period.used}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isExhausted
                        ? AppColors.error
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  ' / ${period.limit}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Progress bar — uses full available card width via LinearProgressIndicator
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSkeletonBar(width: 32, height: 32, borderRadius: 8),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBar(
                        width: 130,
                        height: 13,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 5),
                      _buildSkeletonBar(width: 85, height: 10, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              _buildSkeletonBar(width: 22, height: 22, borderRadius: 11),
            ],
          ),
          const SizedBox(height: 10),

          // Two skeleton period cards side-by-side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSkeletonPeriodCard(context)),
              const SizedBox(width: 10),
              Expanded(child: _buildSkeletonPeriodCard(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonPeriodCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // title + badge row
          Row(
            children: [
              _buildSkeletonBar(width: 44, height: 11, borderRadius: 4),
              const SizedBox(width: 6),
              _buildSkeletonBar(width: 48, height: 15, borderRadius: 5),
            ],
          ),
          const SizedBox(height: 6),
          _buildSkeletonBar(width: 52, height: 13, borderRadius: 4),
          const SizedBox(height: 7),
          _buildSkeletonBar(height: 5, borderRadius: 3),
        ],
      ),
    );
  }

  Widget _buildSkeletonBar({
    double width = double.infinity,
    required double height,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  // ── Error card ────────────────────────────────────────────────────────────

  Widget _buildErrorCard(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.error_warning_line,
                  color: AppColors.error,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lead Generation Quota',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Unable to load quota',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    ref.read(leadLimitProvider.notifier).fetchLimits(),
                icon: const Icon(Remix.refresh_line, size: 14),
                label: Text(
                  'Retry',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Two error placeholder cards side-by-side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildErrorPlaceholder(
                  context,
                  'Today',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildErrorPlaceholder(
                  context,
                  'This Month',
                  const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder(
    BuildContext context,
    String title,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '—',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 0,
              backgroundColor: Colors.black.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(
                accentColor.withValues(alpha: 0.3),
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
