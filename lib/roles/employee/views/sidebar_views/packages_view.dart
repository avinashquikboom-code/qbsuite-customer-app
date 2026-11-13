import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/roles/employee/models/package_model.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/package_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/empty_state_card.dart';

enum PackageSortOption { nameAsc, priceLowToHigh, priceHighToLow, durationDesc }

class PackagesView extends ConsumerStatefulWidget {
  const PackagesView({super.key});

  @override
  ConsumerState<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends ConsumerState<PackagesView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
  PackageSortOption _sortOption = PackageSortOption.nameAsc;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatNumber(double val) {
    final intVal = val.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;

    // Indian currency comma formatting
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
    final packages = ref.watch(packagesProvider);

    // Metrics
    final totalPackages = packages.length;
    final activePackages = packages.where((p) => p.isActive).length;
    final inactivePackages = totalPackages - activePackages;

    // Filter
    var filtered = packages.where((p) {
      final matchStatus = _statusFilter == 'ALL' || p.status == _statusFilter;
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty || p.matchesQuery(q);
      return matchStatus && matchSearch;
    }).toList();

    // Sort
    switch (_sortOption) {
      case PackageSortOption.nameAsc:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case PackageSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
        break;
      case PackageSortOption.priceHighToLow:
        filtered.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
        break;
      case PackageSortOption.durationDesc:
        filtered.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    final rbac = ref.watch(permissionManagerProvider);
    final canCreate = rbac.canCreate(AppModule.packages);
    final canEdit = rbac.canEdit(AppModule.packages);
    final canDelete = rbac.canDelete(AppModule.packages);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Packages'),
      floatingActionButton: canCreate
          ? Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPackageModal(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Remix.add_line,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Package',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // ── Search & Segmented Filter Header ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                // Search bar + Sort
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.pillBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _search = v),
                          style: GoogleFonts.outfit(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search packages or modules…',
                            hintStyle: GoogleFonts.outfit(
                              color: AppColors.textPlaceholder,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Remix.search_2_line,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Remix.close_circle_line,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _search = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSortButton(context),
                  ],
                ),
                const SizedBox(height: 12),

                // Redesigned Segmented Status Filter Bar
                _buildSegmentedFilter(
                  total: totalPackages,
                  active: activePackages,
                  inactive: inactivePackages,
                ),
              ],
            ),
          ),

          // ── Package Cards List ─────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyStateCard(
                          title: _search.isNotEmpty
                              ? 'No matching packages'
                              : 'No packages found',
                          description: _search.isNotEmpty
                              ? 'Try adjusting your search query or filter.'
                              : 'Create your first package to attach to customer proposals.',
                          icon: Remix.price_tag_3_line,
                        ),
                        if (_search.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openPackageModal(context),
                            icon: const Icon(Remix.add_line, size: 16),
                            label: const Text('Create New Package'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final pkg = filtered[i];
                      return _RedesignedPackageCard(
                            package: pkg,
                            formatNumber: _formatNumber,
                            onTap: () => _showPackageDetailsSheet(
                              context,
                              pkg,
                              canEdit: canEdit,
                              canCreate: canCreate,
                            ),
                            onEdit: canEdit
                                ? () => _openPackageModal(context, pkg: pkg)
                                : null,
                            onDuplicate: canCreate
                                ? () {
                                    ref
                                        .read(packagesProvider.notifier)
                                        .duplicatePackage(pkg);
                                    AppToast.success(
                                      context,
                                      'Package duplicated!',
                                    );
                                  }
                                : null,
                            onToggleStatus: canEdit
                                ? () {
                                    ref
                                        .read(packagesProvider.notifier)
                                        .toggleStatus(pkg.id);
                                    AppToast.info(
                                      context,
                                      pkg.isActive
                                          ? 'Package set to Inactive'
                                          : 'Package activated!',
                                    );
                                  }
                                : null,
                            onDelete: canDelete
                                ? () => _confirmDeletePackage(context, pkg)
                                : null,
                          )
                          .animate()
                          .fadeIn(duration: 250.ms, delay: (i * 50).ms)
                          .slideY(
                            begin: 0.05,
                            end: 0,
                            duration: 250.ms,
                            delay: (i * 50).ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter({
    required int total,
    required int active,
    required int inactive,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          _buildSegmentItem(
            label: 'All',
            value: 'ALL',
            count: total,
            icon: Remix.apps_2_line,
            accentColor: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          _buildSegmentItem(
            label: 'Active',
            value: 'ACTIVE',
            count: active,
            icon: Remix.checkbox_circle_fill,
            accentColor: AppColors.primary,
            hasDot: true,
          ),
          const SizedBox(width: 4),
          _buildSegmentItem(
            label: 'Inactive',
            value: 'INACTIVE',
            count: inactive,
            icon: Remix.pause_circle_line,
            accentColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem({
    required String label,
    required String value,
    required int count,
    required IconData icon,
    required Color accentColor,
    bool hasDot = false,
  }) {
    final isSelected = _statusFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 5),
              ] else ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryLight
                      : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    return PopupMenuButton<PackageSortOption>(
      icon: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppColors.pillBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Icon(
          Remix.arrow_up_down_line,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
      initialValue: _sortOption,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (opt) => setState(() => _sortOption = opt),
      itemBuilder: (ctx) => [
        _buildSortMenuItem(
          PackageSortOption.nameAsc,
          'Name (A to Z)',
          Remix.sort_asc,
        ),
        _buildSortMenuItem(
          PackageSortOption.priceHighToLow,
          'Price: High to Low',
          Remix.arrow_down_line,
        ),
        _buildSortMenuItem(
          PackageSortOption.priceLowToHigh,
          'Price: Low to High',
          Remix.arrow_up_line,
        ),
        _buildSortMenuItem(
          PackageSortOption.durationDesc,
          'Duration: Longest first',
          Remix.time_line,
        ),
      ],
    );
  }

  PopupMenuItem<PackageSortOption> _buildSortMenuItem(
    PackageSortOption value,
    String title,
    IconData icon,
  ) {
    final isSelected = _sortOption == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _openPackageModal(BuildContext context, {PackageModel? pkg}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PackageFormSheet(
        initialPackage: pkg,
        onSave: (savedPkg) {
          if (pkg == null) {
            ref.read(packagesProvider.notifier).addPackage(savedPkg);
            AppToast.success(context, 'Package "${savedPkg.name}" created!');
          } else {
            ref.read(packagesProvider.notifier).updatePackage(savedPkg);
            AppToast.success(context, 'Package "${savedPkg.name}" updated!');
          }
        },
      ),
    );
  }

  void _showPackageDetailsSheet(
    BuildContext context,
    PackageModel pkg, {
    required bool canEdit,
    required bool canCreate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PackageDetailsSheet(
        package: pkg,
        formatNumber: _formatNumber,
        onEdit: canEdit
            ? () {
                Navigator.pop(ctx);
                _openPackageModal(context, pkg: pkg);
              }
            : null,
        onDuplicate: canCreate
            ? () {
                Navigator.pop(ctx);
                ref.read(packagesProvider.notifier).duplicatePackage(pkg);
                AppToast.success(context, 'Package duplicated!');
              }
            : null,
        onToggleStatus: canEdit
            ? () {
                Navigator.pop(ctx);
                ref.read(packagesProvider.notifier).toggleStatus(pkg.id);
                AppToast.info(
                  context,
                  pkg.isActive
                      ? 'Package set to Inactive'
                      : 'Package activated!',
                );
              }
            : null,
      ),
    );
  }

  void _confirmDeletePackage(BuildContext context, PackageModel pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.delete_bin_line,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Package?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${pkg.name}"? This action cannot be undone.',
          style: GoogleFonts.outfit(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(packagesProvider.notifier).deletePackage(pkg.id);
              AppToast.success(context, 'Package deleted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Package Card
// ─────────────────────────────────────────────────────────────────────────────
class _RedesignedPackageCard extends StatefulWidget {
  final PackageModel package;
  final String Function(double) formatNumber;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onDelete;

  const _RedesignedPackageCard({
    required this.package,
    required this.formatNumber,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onToggleStatus,
    this.onDelete,
  });

  @override
  State<_RedesignedPackageCard> createState() => _RedesignedPackageCardState();
}

class _RedesignedPackageCardState extends State<_RedesignedPackageCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final isEnterprise = pkg.name.toLowerCase().contains('enterprise');
    final isPro =
        pkg.name.toLowerCase().contains('professional') ||
        pkg.name.toLowerCase().contains('pro');

    // Gradient per tier
    final gradientColors = isEnterprise
        ? [AppColors.tierEnterpriseDark, AppColors.tierEnterpriseLight]
        : isPro
        ? [AppColors.tierProDark, AppColors.tierProLight]
        : [AppColors.primaryDark, AppColors.primary];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pkg.isActive ? AppColors.borderLight : AppColors.borderMuted,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Gradient Accent Header ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEnterprise
                        ? Remix.vip_crown_2_line
                        : isPro
                        ? Remix.shield_flash_line
                        : Remix.rocket_2_line,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${pkg.id.toUpperCase()}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pkg.isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pkg.isActive
                              ? AppColors.primary
                              : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pkg.status,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pkg.isActive
                              ? AppColors.primaryDark
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Overflow options menu
                if (widget.onEdit != null ||
                    widget.onDuplicate != null ||
                    widget.onToggleStatus != null ||
                    widget.onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Remix.more_2_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEdit?.call();
                          break;
                        case 'duplicate':
                          widget.onDuplicate?.call();
                          break;
                        case 'status':
                          widget.onToggleStatus?.call();
                          break;
                        case 'delete':
                          widget.onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (widget.onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(
                                Remix.edit_line,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Package',
                                style: GoogleFonts.outfit(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      if (widget.onDuplicate != null)
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              const Icon(
                                Remix.file_copy_line,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Duplicate',
                                style: GoogleFonts.outfit(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      if (widget.onToggleStatus != null)
                        PopupMenuItem(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(
                                pkg.isActive
                                    ? Remix.pause_circle_line
                                    : Remix.play_circle_line,
                                size: 16,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                pkg.isActive ? 'Mark Inactive' : 'Mark Active',
                                style: GoogleFonts.outfit(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      if (widget.onDelete != null) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Remix.delete_bin_line,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),

          // ── Main Card Body ──────────────────────────────────────────
          InkWell(
            onTap: widget.onTap,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (pkg.description.isNotEmpty) ...[
                    Text(
                      pkg.description,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Price & Duration Strip ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Total Price Focus
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL INVESTMENT',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${widget.formatNumber(pkg.totalPrice)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'incl. ${pkg.gstPercent.toStringAsFixed(0)}% GST (₹${widget.formatNumber(pkg.gstAmount)})',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Duration Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderMuted),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Remix.calendar_event_line,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                pkg.durationLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Included Modules Overview ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Remix.stack_line,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Included Features (${pkg.items.length})',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (pkg.items.isNotEmpty)
                        InkWell(
                          onTap: () {
                            setState(() => _isExpanded = !_isExpanded);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _isExpanded ? 'Collapse' : 'Breakdown',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _isExpanded
                                      ? Remix.arrow_up_s_line
                                      : Remix.arrow_down_s_line,
                                  size: 16,
                                  color: AppColors.primaryDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Features Pills Preview
                  if (!_isExpanded)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: pkg.items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Remix.check_line,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.quantity > 1
                                    ? '${item.name} (${item.quantity}×)'
                                    : item.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    // Expanded Detailed Items Breakdown List
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: pkg.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Remix.check_line,
                                    size: 12,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.quantity} × ₹${widget.formatNumber(item.unitPrice)} (${item.planType})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),

                  // Bottom Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Base: ₹${widget.formatNumber(pkg.basePrice)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Remix.eye_line, size: 14),
                        label: const Text('View Specs'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          textStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package Details Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PackageDetailsSheet extends StatelessWidget {
  final PackageModel package;
  final String Function(double) formatNumber;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleStatus;

  const _PackageDetailsSheet({
    required this.package,
    required this.formatNumber,
    this.onEdit,
    this.onDuplicate,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Remix.price_tag_3_line,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${package.id.toUpperCase()} • ${package.durationLabel}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Remix.close_line,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (package.description.isNotEmpty) ...[
                      Text(
                        'Package Overview',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          package.description,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Included Modules Table
                    Text(
                      'Included Modules & Pricing Items',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.pillBg,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(13),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'MODULE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'QTY',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'RATE',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...package.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          item.planType,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.unitPrice == 0
                                          ? 'Included'
                                          : '₹${formatNumber(item.total)}',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: item.unitPrice == 0
                                            ? AppColors.primaryDark
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Financial Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryLine(
                            'Base Price',
                            '₹${formatNumber(package.basePrice)}',
                          ),
                          const SizedBox(height: 6),
                          _buildSummaryLine(
                            'GST (${package.gstPercent.toStringAsFixed(0)}%)',
                            '₹${formatNumber(package.gstAmount)}',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              color: AppColors.borderMuted,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Grand Total',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '₹${formatNumber(package.totalPrice)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (onDuplicate != null || onEdit != null)
                      Row(
                        children: [
                          if (onDuplicate != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onDuplicate,
                                icon: const Icon(
                                  Remix.file_copy_line,
                                  size: 16,
                                ),
                                label: const Text('Duplicate'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (onDuplicate != null && onEdit != null)
                            const SizedBox(width: 10),
                          if (onEdit != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: onEdit,
                                icon: const Icon(Remix.edit_line, size: 16),
                                label: const Text('Edit Package'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create & Edit Package Modal Form Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PackageFormSheet extends StatefulWidget {
  final PackageModel? initialPackage;
  final void Function(PackageModel) onSave;

  const _PackageFormSheet({this.initialPackage, required this.onSave});

  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _gstCtrl;
  late String _durationType;
  late String _status;

  final List<Map<String, TextEditingController>> _items = [];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPackage;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _durationCtrl = TextEditingController(
      text: p != null ? '${p.duration}' : '12',
    );
    _priceCtrl = TextEditingController(
      text: p != null ? p.basePrice.toStringAsFixed(0) : '',
    );
    _gstCtrl = TextEditingController(
      text: p != null ? p.gstPercent.toStringAsFixed(0) : '18',
    );
    _durationType = p?.durationType ?? 'Months';
    _status = p?.status ?? 'ACTIVE';

    if (p != null && p.items.isNotEmpty) {
      for (final item in p.items) {
        _items.add({
          'name': TextEditingController(text: item.name),
          'qty': TextEditingController(text: '${item.quantity}'),
          'price': TextEditingController(
            text: item.unitPrice.toStringAsFixed(0),
          ),
          'planType': TextEditingController(text: item.planType),
        });
      }
    } else {
      // Default initial starter items
      _addItemWithValues('CRM Cloud', 1, 30000, 'Yearly');
      _addItemWithValues('User Seats', 5, 4000, 'Yearly');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    _gstCtrl.dispose();
    for (final item in _items) {
      item['name']!.dispose();
      item['qty']!.dispose();
      item['price']!.dispose();
      item['planType']!.dispose();
    }
    super.dispose();
  }

  void _addItemWithValues(String name, int qty, double price, String planType) {
    _items.add({
      'name': TextEditingController(text: name),
      'qty': TextEditingController(text: '$qty'),
      'price': TextEditingController(text: price.toStringAsFixed(0)),
      'planType': TextEditingController(text: planType),
    });
  }

  void _addItem() {
    setState(() {
      _items.add({
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'price': TextEditingController(text: '0'),
        'planType': TextEditingController(text: 'Yearly'),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index]['name']!.dispose();
      _items[index]['qty']!.dispose();
      _items[index]['price']!.dispose();
      _items[index]['planType']!.dispose();
      _items.removeAt(index);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final pkgId =
        widget.initialPackage?.id ??
        'pkg-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final items = _items.asMap().entries.map((e) {
      final i = e.key;
      final ctrl = e.value;
      return PackageItemModel(
        id: '$pkgId-item-$i',
        packageId: pkgId,
        name: ctrl['name']!.text.trim(),
        quantity: int.tryParse(ctrl['qty']!.text) ?? 1,
        planType: ctrl['planType']!.text.trim().isEmpty
            ? 'Yearly'
            : ctrl['planType']!.text.trim(),
        unitPrice: double.tryParse(ctrl['price']!.text) ?? 0,
      );
    }).toList();

    final basePrice = double.tryParse(_priceCtrl.text) ?? 0;
    final gstPercent = double.tryParse(_gstCtrl.text) ?? 18;

    final pkg = PackageModel(
      id: pkgId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      duration: int.tryParse(_durationCtrl.text) ?? 12,
      durationType: _durationType,
      basePrice: basePrice,
      gstPercent: gstPercent,
      status: _status,
      createdAt:
          widget.initialPackage?.createdAt ?? DateTime.now().toIso8601String(),
      items: items,
    );

    widget.onSave(pkg);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initialPackage != null;

    final basePrice = double.tryParse(_priceCtrl.text) ?? 0;
    final gstPercent = double.tryParse(_gstCtrl.text) ?? 18;
    final totalPreview = basePrice * (1 + (gstPercent / 100));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Remix.edit_box_line : Remix.add_box_line,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Package' : 'Create New Package',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Remix.close_line,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPad),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'General Info',
                        Remix.information_line,
                      ),
                      const SizedBox(height: 10),
                      _fieldLabel('Package Name *'),
                      _buildTextField(
                        _nameCtrl,
                        'e.g. CRM Growth Suite',
                        required: true,
                        prefixIcon: Remix.price_tag_line,
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel('Description'),
                      _buildTextField(
                        _descCtrl,
                        'Key highlights and benefits included in this offering…',
                        maxLines: 2,
                        prefixIcon: Remix.file_text_line,
                      ),
                      const SizedBox(height: 16),

                      _buildSectionHeader(
                        'Billing & Term',
                        Remix.calendar_check_line,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Duration *'),
                                _buildTextField(
                                  _durationCtrl,
                                  '12',
                                  keyboardType: TextInputType.number,
                                  required: true,
                                  prefixIcon: Remix.time_line,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Period Type'),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.borderMuted,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _durationType,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Months',
                                        child: Text('Months'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Years',
                                        child: Text('Years'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Days',
                                        child: Text('Days'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _durationType = v!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Base Price (₹) *'),
                                _buildTextField(
                                  _priceCtrl,
                                  '50000',
                                  keyboardType: TextInputType.number,
                                  required: true,
                                  prefixIcon: Remix.money_rupee_circle_line,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('GST (%)'),
                                _buildTextField(
                                  _gstCtrl,
                                  '18',
                                  keyboardType: TextInputType.number,
                                  prefixIcon: Remix.percent_line,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Live calculated total card
                      if (basePrice > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Calculated Total (incl. GST):',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '₹${totalPreview.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      _fieldLabel('Status'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderMuted),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'ACTIVE',
                              child: Text('Active (Visible in Proposals)'),
                            ),
                            DropdownMenuItem(
                              value: 'INACTIVE',
                              child: Text('Inactive (Draft / Archived)'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Included Modules Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            'Modules & Features',
                            Remix.stack_line,
                          ),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Remix.add_line, size: 16),
                            label: const Text('Add Feature'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      for (int i = 0; i < _items.length; i++)
                        _buildItemBuilderCard(i),

                      const SizedBox(height: 24),

                      // Submit button
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _save,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isEdit
                                              ? Remix.checkbox_circle_line
                                              : Remix.add_circle_line,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEdit
                                              ? 'Save Changes'
                                              : 'Create Package',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildItemBuilderCard(int index) {
    final ctrl = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: ctrl['name'],
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: _inputDecoration('Feature / Module Name'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextFormField(
                  controller: ctrl['qty'],
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: _inputDecoration('Qty'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Remix.delete_bin_line,
                  color: AppColors.error,
                  size: 18,
                ),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: ctrl['price'],
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: _inputDecoration('Unit Rate (₹)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: ctrl['planType'],
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: _inputDecoration('Billing Cycle (e.g. Yearly)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  TextFormField _buildTextField(
    TextEditingController ctrl,
    String hint, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 13),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: _inputDecoration(hint, prefixIcon: prefixIcon),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        color: AppColors.textPlaceholder,
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 16, color: AppColors.textSecondary)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderMuted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderMuted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    );
  }
}
