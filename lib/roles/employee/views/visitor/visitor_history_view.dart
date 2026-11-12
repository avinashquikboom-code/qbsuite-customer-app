import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/empty_state_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'visitor_visit_details_view.dart';

class VisitorHistoryView extends ConsumerStatefulWidget {
  const VisitorHistoryView({super.key});

  @override
  ConsumerState<VisitorHistoryView> createState() => _VisitorHistoryViewState();
}

class _VisitorHistoryViewState extends ConsumerState<VisitorHistoryView> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _completedVisits = [];
  List<Map<String, dynamic>> _scheduledVisits = [];
  List<Map<String, dynamic>> _ongoingVisits = [];
  String _selectedFilter = 'Completed';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = [
    'All',
    'Scheduled',
    'Ongoing',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'completed'}),
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'upcoming'}),
        ref
            .read(apiClientProvider)
            .get('/mobile/visits', queryParameters: {'tab': 'ongoing'}),
      ]);

      List<Map<String, dynamic>> parseItems(dynamic res) {
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
        final List<dynamic> items = raw is List ? raw : [];
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (mounted) {
        setState(() {
          _completedVisits = parseItems(results[0]);
          _scheduledVisits = parseItems(results[1]);
          _ongoingVisits = parseItems(results[2]);
        });
      }
    } catch (e) {
      debugPrint('[VisitorHistoryView] _fetchHistory error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredVisits() {
    List<Map<String, dynamic>> baseList;
    if (_selectedFilter == 'All') {
      baseList = [..._completedVisits, ..._ongoingVisits, ..._scheduledVisits];
    } else if (_selectedFilter == 'Scheduled') {
      baseList = _scheduledVisits;
    } else if (_selectedFilter == 'Ongoing') {
      baseList = _ongoingVisits;
    } else {
      baseList = _completedVisits;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      baseList = baseList.where((v) {
        final cust = (v['customer'] ?? v['customerName'] ?? '')
            .toString()
            .toLowerCase();
        final purpose = (v['purpose'] ?? '').toString().toLowerCase();
        final loc = (v['location'] ?? '').toString().toLowerCase();
        final outcome = (v['outcome'] ?? '').toString().toLowerCase();
        return cust.contains(q) ||
            purpose.contains(q) ||
            loc.contains(q) ||
            outcome.contains(q);
      }).toList();
    }

    return baseList;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredVisits();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Visit History', showBackButton: false),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search & Filter Tabs Bar ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  // Search field
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by client, purpose or location...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Remix.search_2_line,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Remix.close_circle_fill,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips: All | Scheduled | Ongoing | Completed
                  Row(
                    children: _filterOptions.map((opt) {
                      return _buildFilterChip(opt);
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ── Main Content List ──────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const SkeletonList(count: 4)
                  : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: EmptyStateCard(
                                icon: Remix.history_line,
                                title: 'No Visits Found',
                                description: _searchQuery.isNotEmpty
                                    ? 'No visits match "$_searchQuery".'
                                    : 'No visits found under $_selectedFilter category.',
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final visit = filtered[index];
                        return _buildHistoryCard(visit);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: () => setState(() => _selectedFilter = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF16A34A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : AppColors.borderLight,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> visit) {
    final customer =
        visit['customer']?.toString() ??
        visit['customerName']?.toString() ??
        'Sharma Enterprises';
    final purpose = visit['purpose']?.toString() ?? 'E-commerce Website';
    final location = visit['location']?.toString() ?? 'Delhi';
    final dateStr = visit['date']?.toString() ?? '25 Sep 2025';
    final statusStr = visit['status']?.toString() ?? 'Completed';
    final outcome = visit['outcome']?.toString() ?? '';

    int rating = 5;
    if (visit['rating'] is int) {
      rating = visit['rating'];
    } else if (visit['rating'] != null) {
      rating = int.tryParse(visit['rating'].toString()) ?? 5;
    }

    String displayStatus = 'Interested';
    if (outcome.isNotEmpty) {
      if (outcome.toLowerCase().contains('not interested')) {
        displayStatus = 'Not Interested';
      } else if (outcome.toLowerCase().contains('follow-up') ||
          outcome.toLowerCase().contains('follow up')) {
        displayStatus = 'Follow-up';
      } else if (outcome.toLowerCase().contains('interested')) {
        displayStatus = 'Interested';
      } else if (outcome.contains(':')) {
        displayStatus = outcome.split(':').first.trim();
      } else if (outcome.length > 18) {
        displayStatus = outcome.substring(0, 18).trim();
      } else {
        displayStatus = outcome;
      }
    } else if (statusStr.toUpperCase() == 'COMPLETED') {
      displayStatus = 'Interested';
    } else if (statusStr.toUpperCase() == 'IN_PROGRESS' ||
        statusStr.toUpperCase() == 'ONGOING') {
      displayStatus = 'Ongoing';
    } else {
      displayStatus = 'Scheduled';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VisitorVisitDetailsView(
                  visit: visit,
                  onVisitUpdated: _fetchHistory,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                        customer,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        purpose,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr | $location',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayStatus,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    displayStatus.toLowerCase().contains('not')
                                    ? const Color(0xFFDC2626)
                                    : (displayStatus.toLowerCase().contains(
                                            'follow',
                                          )
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF16A34A)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '|',
                            style: GoogleFonts.outfit(
                              color: AppColors.borderLight,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Remix.star_fill,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$rating',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Remix.arrow_right_s_line,
                  size: 20,
                  color: AppColors.textPlaceholder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
