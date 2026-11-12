import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/status_badge.dart';
import 'package:quickboom_crm_customer/shared/widgets/empty_state_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_profile_viewmodel.dart';

import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'visitor/visitor_visit_details_view.dart';
import 'visitor/visitor_requirement_view.dart';

class VisitsView extends ConsumerStatefulWidget {
  const VisitsView({super.key});

  @override
  ConsumerState<VisitsView> createState() => _VisitsViewState();
}

class _VisitsViewState extends ConsumerState<VisitsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _completedFilter = 'All';
  bool _isLoading = false;
  String? _errorMessage;

  // Real data from API
  List<Map<String, dynamic>> _upcomingVisits = [];
  List<Map<String, dynamic>> _ongoingVisits = [];
  List<Map<String, dynamic>> _completedVisits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'upcoming'}),
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'ongoing'}),
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'completed'}),
      ]);

      List<Map<String, dynamic>> parseList(dynamic res) {
        dynamic raw = res is Map ? res : res.data;
        if (raw is Map &&
            raw.containsKey('data') &&
            (raw['data'] is List || raw['data'] is Map)) {
          raw = raw['data'];
        }
        if (raw is Map && raw.containsKey('items') && raw['items'] is List) {
          raw = raw['items'];
        } else if (raw is Map &&
            raw.containsKey('data') &&
            raw['data'] is List) {
          raw = raw['data'];
        }
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [];
      }

      if (mounted) {
        setState(() {
          _upcomingVisits = parseList(results[0]);
          _ongoingVisits = parseList(results[1]);
          _completedVisits = parseList(results[2]);
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[VisitsView] _fetchAllVisits error: $e');
      if (mounted) {
        setState(
          () => _errorMessage =
              'Unable to load visits. Please check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStartVisit(Map<String, dynamic> visit) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start Field Visit',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify GPS and confirm arrival at customer site.',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Remix.map_pin_2_line, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit['customer']?.toString() ?? 'Customer',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            visit['location']?.toString() ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(apiClientProvider)
                          .patch(
                            '/mobile/visits/${visit['id']}/check-in',
                            data: {},
                          );
                      if (mounted) {
                        AppToast.success(
                          context,
                          'Field visit started with GPS check-in.',
                          title: 'Visit Started',
                        );
                      }
                      _fetchAllVisits();
                    } catch (e) {
                      if (mounted) {
                        AppToast.error(context, 'Check-in failed: $e');
                      }
                    }
                  },
                  icon: const Icon(Remix.play_fill),
                  label: const Text('Confirm & Check In'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCompleteVisit(
    Map<String, dynamic> visit, {
    bool isVisitor = false,
  }) async {}

  void _openVisitDetailsSheet(
    Map<String, dynamic> visit, {
    required bool isVisitor,
    required bool isUpcoming,
    required bool isOngoing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      visit['customer']?.toString() ?? 'Customer Visit',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label: visit['status']?.toString() ?? 'SCHEDULED',
                    type: isUpcoming
                        ? BadgeType.scheduled
                        : (isOngoing
                              ? BadgeType.inProgress
                              : BadgeType.completed),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visit['purpose'] != null &&
                  visit['purpose'].toString().isNotEmpty) ...[
                Text(
                  visit['purpose'].toString(),
                  style: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Remix.time_line,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${visit['date'] ?? ''} at ${visit['time'] ?? ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Remix.map_pin_line,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            visit['location']?.toString() ?? 'N/A',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (visit['assignedEmployee'] != null &&
                  visit['assignedEmployee'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Remix.user_3_line,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      visit['status']?.toString().toUpperCase() == 'COMPLETED'
                          ? 'Completed By: ${visit['completedBy'] ?? visit['assignedEmployee']}'
                          : 'Visitor: ${visit['assignedEmployee']}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
              if (visit['completedAtFormatted'] != null ||
                  visit['completedAt'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Remix.check_double_line,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Completed: ${visit['completedAtFormatted'] ?? visit['completedAt']}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
              if (visit['outcome'] != null &&
                  (visit['outcome'] as String).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Outcome: ${visit['outcome']}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (visit['notes'] != null &&
                  (visit['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Notes:',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${visit['notes']}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isUpcoming || isOngoing) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isVisitor) {
                        _handleCompleteVisit(visit, isVisitor: true);
                      } else if (isUpcoming) {
                        _handleStartVisit(visit);
                      } else {
                        _handleCompleteVisit(visit, isVisitor: false);
                      }
                    },
                    icon: Icon(
                      isVisitor || isOngoing
                          ? Remix.checkbox_circle_line
                          : Remix.play_fill,
                      size: 18,
                    ),
                    label: Text(
                      isVisitor
                          ? (isUpcoming ? 'Enter Visit' : 'Mark Visit Done')
                          : (isUpcoming ? 'Start Visit' : 'Complete Visit'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVisitor || isOngoing
                          ? AppColors.success
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Resolve Visitor identification from existing provider ───────────────
    final profile = ref.watch(employeeProfileProvider).asData?.value;
    final rbacPerms = ref.watch(permissionManagerProvider);
    final desigName = (profile?.designation ?? '').trim().toUpperCase();
    final roleName = (rbacPerms.role ?? '').trim().toUpperCase();
    final isVisitor =
        desigName.contains('VISITOR') ||
        desigName == 'VISIT' ||
        desigName.contains('FIELD VISIT') ||
        roleName.contains('VISITOR') ||
        roleName == 'VISIT';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: AppBarTitles.visits,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line),
            onPressed: _fetchAllVisits,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: isVisitor ? 'Scheduled' : 'Upcoming'),
            const Tab(text: 'Ongoing'),
            const Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const SkeletonList(count: 4)
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Remix.error_warning_line,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchAllVisits,
                      icon: const Icon(Remix.refresh_line, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVisitsList(
                  'upcoming',
                  _upcomingVisits,
                  isVisitor: isVisitor,
                ),
                _buildVisitsList(
                  'ongoing',
                  _ongoingVisits,
                  isVisitor: isVisitor,
                ),
                _buildVisitsList(
                  'completed',
                  _completedVisits,
                  isVisitor: isVisitor,
                ),
              ],
            ),
    );
  }

  Widget _buildVisitsList(
    String tabCategory,
    List<Map<String, dynamic>> visits, {
    bool isVisitor = false,
  }) {
    // Completed tab: local date filter
    List<Map<String, dynamic>> filtered = visits;
    if (tabCategory == 'completed') {
      final today = DateTime.now();
      final todayDay = today.day.toString();
      final todayIso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      filtered = visits.where((v) {
        if (_completedFilter == 'All') {
          return true;
        }
        if (_completedFilter == 'Today') {
          final completedAtRaw = v['completedAt']?.toString();
          if (completedAtRaw != null && completedAtRaw.isNotEmpty) {
            final dt = DateTime.tryParse(completedAtRaw)?.toLocal();
            if (dt != null) {
              return dt.year == today.year &&
                  dt.month == today.month &&
                  dt.day == today.day;
            }
          }
          final updatedAtRaw = v['updatedAt']?.toString();
          if (updatedAtRaw != null && updatedAtRaw.isNotEmpty) {
            final dt = DateTime.tryParse(updatedAtRaw)?.toLocal();
            if (dt != null) {
              return dt.year == today.year &&
                  dt.month == today.month &&
                  dt.day == today.day;
            }
          }
          final dateStr = v['date']?.toString() ?? '';
          return dateStr.toLowerCase().contains('today') ||
              dateStr.contains(todayDay) ||
              (completedAtRaw != null && completedAtRaw.contains(todayIso));
        }
        if (_completedFilter == 'Week') {
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          final startOfWeekDay = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          final completedAtRaw =
              v['completedAt']?.toString() ?? v['updatedAt']?.toString();
          if (completedAtRaw != null && completedAtRaw.isNotEmpty) {
            final dt = DateTime.tryParse(completedAtRaw)?.toLocal();
            if (dt != null) {
              return dt.isAfter(
                startOfWeekDay.subtract(const Duration(seconds: 1)),
              );
            }
          }
          return true;
        }
        if (_completedFilter == 'Month') {
          final startOfMonth = DateTime(today.year, today.month, 1);
          final completedAtRaw =
              v['completedAt']?.toString() ?? v['updatedAt']?.toString();
          if (completedAtRaw != null && completedAtRaw.isNotEmpty) {
            final dt = DateTime.tryParse(completedAtRaw)?.toLocal();
            if (dt != null) {
              return dt.isAfter(
                startOfMonth.subtract(const Duration(seconds: 1)),
              );
            }
          }
          return true;
        }
        return true;
      }).toList();
    }

    Widget content;
    if (filtered.isEmpty) {
      final sectionLabel = (isVisitor && tabCategory == 'upcoming')
          ? 'Scheduled'
          : tabCategory;
      content = RefreshIndicator(
        onRefresh: _fetchAllVisits,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyStateCard(
                    icon: Remix.briefcase_line,
                    title: 'No Visits Found',
                    description:
                        'No field meetings present under the $sectionLabel section.',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _fetchAllVisits,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final visit = filtered[index];
            final isUpcoming = tabCategory == 'upcoming';
            final isOngoing = tabCategory == 'ongoing';

            if (isVisitor) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VisitorVisitDetailsView(
                            visit: visit,
                            onVisitUpdated: _fetchAllVisits,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Remix.building_line,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visit['customer']?.toString() ??
                                      visit['customerName']?.toString() ??
                                      'Sharma Enterprises',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  visit['purpose']?.toString() ?? 'Field Visit',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${visit['time'] ?? '10:00 AM'} | ${visit['location'] ?? 'Delhi'}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (visit['phone'] != null &&
                                    visit['phone'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    visit['phone'].toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(
                                Remix.arrow_right_s_line,
                                size: 20,
                                color: AppColors.textPlaceholder,
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'View',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _openVisitDetailsSheet(
                      visit,
                      isVisitor: isVisitor,
                      isUpcoming: isUpcoming,
                      isOngoing: isOngoing,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                visit['customer']?.toString() ?? 'Customer',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge(
                              label: visit['status']?.toString() ?? 'SCHEDULED',
                              type: isUpcoming
                                  ? BadgeType.scheduled
                                  : (isOngoing
                                        ? BadgeType.inProgress
                                        : BadgeType.completed),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          visit['purpose']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Remix.time_line,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${visit['date'] ?? ''} at ${visit['time'] ?? ''}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Remix.map_pin_line,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visit['location']?.toString() ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (visit['phone'] != null &&
                            visit['phone'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Remix.phone_line,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  visit['phone'].toString(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isVisitor) ...[
                                InkWell(
                                  onTap: () {
                                    final p = visit['phone']
                                        .toString()
                                        .replaceAll(RegExp(r'[^0-9+]'), '');
                                    launchUrl(Uri.parse('tel:$p'));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Remix.phone_fill,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Call',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        // Completed Details
                        if (tabCategory == 'completed') ...[
                          if (visit['assignedEmployee'] != null &&
                              visit['assignedEmployee']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Remix.user_3_line,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Completed By: ${visit['completedBy'] ?? visit['assignedEmployee']}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (visit['completedAtFormatted'] != null ||
                              visit['completedAt'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Remix.check_double_line,
                                  size: 15,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Completed: ${visit['completedAtFormatted'] ?? visit['completedAt']}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (visit['outcome'] != null &&
                              (visit['outcome'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Outcome: ${visit['outcome']}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (visit['notes'] != null &&
                              (visit['notes'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Notes: ${visit['notes']}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                        if (isUpcoming ||
                            isOngoing ||
                            (isVisitor && tabCategory == 'completed')) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (isVisitor) {
                                  if (isUpcoming) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VisitorVisitDetailsView(
                                          visit: visit,
                                          onVisitUpdated: _fetchAllVisits,
                                        ),
                                      ),
                                    );
                                  } else if (isOngoing) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VisitorRequirementView(
                                          visit: visit,
                                          onVisitUpdated: _fetchAllVisits,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VisitorVisitDetailsView(
                                          visit: visit,
                                          onVisitUpdated: _fetchAllVisits,
                                        ),
                                      ),
                                    );
                                  }
                                } else if (isUpcoming) {
                                  _handleStartVisit(visit);
                                } else {
                                  _handleCompleteVisit(visit, isVisitor: false);
                                }
                              },
                              icon: Icon(
                                isVisitor
                                    ? (isUpcoming
                                          ? Remix.arrow_right_line
                                          : (isOngoing
                                                ? Remix.file_list_3_line
                                                : Remix.file_text_line))
                                    : (isOngoing
                                          ? Remix.checkbox_circle_line
                                          : Remix.play_fill),
                                size: 18,
                              ),
                              label: Text(
                                isVisitor
                                    ? (isUpcoming
                                          ? 'Enter Visit'
                                          : (isOngoing
                                                ? 'Requirement & Complete'
                                                : 'View Summary'))
                                    : (isUpcoming
                                          ? 'Start Visit'
                                          : 'Complete Visit'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isVisitor || isOngoing
                                    ? AppColors.success
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    if (tabCategory == 'completed') {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeFilterBtn(
                      'All',
                      _completedFilter == 'All',
                    ),
                  ),
                  Expanded(
                    child: _buildTimeFilterBtn(
                      'Today',
                      _completedFilter == 'Today',
                    ),
                  ),
                  Expanded(
                    child: _buildTimeFilterBtn(
                      'Week',
                      _completedFilter == 'Week',
                    ),
                  ),
                  Expanded(
                    child: _buildTimeFilterBtn(
                      'Month',
                      _completedFilter == 'Month',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildTimeFilterBtn(String title, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _completedFilter = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
