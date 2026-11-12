import '../../models/capture_history.dart';
import '../../services/data_capture_records_service.dart';
import 'data_capture_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';
import 'package:quickboom_crm_customer/shared/services/data_capture_service.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/data_capture/capture_usage_card.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';
import 'data_capture_history_screen.dart';
import 'new_data_capture_screen.dart';

class DataCaptureHomeScreen extends StatefulWidget {
  const DataCaptureHomeScreen({super.key});

  @override
  State<DataCaptureHomeScreen> createState() => _DataCaptureHomeScreenState();
}

class _DataCaptureHomeScreenState extends State<DataCaptureHomeScreen> {
  final DataCaptureService _service = DataCaptureService();
  DataCaptureUsage _usage = DataCaptureUsage.initial();
  List<CaptureHistorySession> _recent = const [];
  int _recentTotal = 0;
  bool _isLoading = true;
  bool _recentLoading = true;
  String? _usageError;
  String? _recentError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _recentLoading = true;
      _usageError = null;
      _recentError = null;
    });
    await Future.wait([_loadUsage(), _loadRecent()]);
  }

  Future<void> _loadUsage() async {
    try {
      final usage = await _service.getUsageSummary();
      if (mounted) {
        setState(() {
          _usage = usage;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _usageError = dataCaptureError(error);
        });
      }
    }
  }

  Future<void> _loadRecent() async {
    try {
      final page = await _service.getHistory();
      if (mounted) {
        setState(() {
          _recent = page.sessions.take(5).toList();
          _recentTotal = page.total;
          _recentLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recentLoading = false;
          _recentError = dataCaptureError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: AppBarTitles.dataCapture,
        showBackButton: false,
        showDrawerButton: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F3822),
                      Color(0xFF14532D),
                      Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'GOOGLE PLACES LEAD CAPTURE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.travel_explore_rounded,
                          color: AppColors.primaryLight,
                          size: 26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Find Businesses & Prospects',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find verified businesses and extract prospective leads directly from Google Places into your CRM pipeline.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewDataCaptureScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                        icon: const Icon(Icons.search_rounded, size: 20),
                        label: Text(
                          'Start New Capture',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_usageError != null)
                Text(_usageError!, style: const TextStyle(color: Colors.red))
              else if (!_isLoading)
                CaptureUsageCard(usage: _usage),
              const SizedBox(height: 16),
              if (_usageError == null) _buildMetricsSection(),
              const SizedBox(height: 20),
              _buildRecentCaptures(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataCaptureHistoryScreen()),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return MaterialLocalizations.of(context).formatMediumDate(time);
  }

  Widget _buildRecentCaptures() {
    final total = _recentTotal > 0 ? _recentTotal : _recent.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Captures',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF172033),
                ),
              ),
            ),
            if (total > 0)
              TextButton(
                onPressed: _openHistory,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  'View All ($total)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentLoading)
          const SkeletonList(count: 2, padding: EdgeInsets.zero)
        else if (_recentError != null)
          Text(_recentError!, style: const TextStyle(color: Colors.red))
        else if (_recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No recent captures yet.',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          )
        else
          ..._recent.map(_recentCard),
      ],
    );
  }

  Widget _recentCard(CaptureHistorySession session) {
    final title = session.keyword.trim().isEmpty ? 'Capture' : session.keyword;
    final place = session.location.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: session.jobId.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DataCaptureRecordsScreen(
                      jobId: session.jobId,
                      fromHistory: true,
                    ),
                  ),
                ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F9EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Remix.user_search_line, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF172033)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F9EE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${session.captured} captured',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Remix.map_pin_line, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              place.isEmpty ? '—' : place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Remix.time_line, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            _ago(session.createdAt),
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Remix.arrow_right_s_line, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On very compact screens (< 310px available width, e.g. 320px device width), use tighter padding and gap
        final isCompact = availableWidth < 310;
        final horizontalPadding = isCompact ? 8.0 : 10.0;
        final verticalPadding = isCompact ? 7.0 : 8.0;
        final gap = isCompact ? 6.0 : 8.0;
        final titleFontSize = isCompact ? 10.0 : 11.0;
        final valueFontSize = isCompact ? 15.0 : 16.0;

        if (_isLoading) {
          return Row(
            children: [
              Expanded(
                child: _buildMetricTileSkeleton(
                  horizontalPadding: horizontalPadding,
                  verticalPadding: verticalPadding,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildMetricTileSkeleton(
                  horizontalPadding: horizontalPadding,
                  verticalPadding: verticalPadding,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildMetricTileSkeleton(
                  horizontalPadding: horizontalPadding,
                  verticalPadding: verticalPadding,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                key: const ValueKey('metric_tile_total_captured'),
                title: 'Total Captured',
                value: '${_usage.totalLeadsCaptured}',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                titleFontSize: titleFontSize,
                valueFontSize: valueFontSize,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildMetricTile(
                key: const ValueKey('metric_tile_extractions'),
                title: 'Extractions',
                value: '${_usage.totalExtractions}',
                icon: Icons.history_edu_rounded,
                color: AppColors.secondary,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                titleFontSize: titleFontSize,
                valueFontSize: valueFontSize,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildMetricTile(
                key: const ValueKey('metric_tile_searches'),
                title: 'Searches',
                value: '${_usage.searches}',
                icon: Icons.search_rounded,
                color: AppColors.primary,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                titleFontSize: titleFontSize,
                valueFontSize: valueFontSize,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTileSkeleton({
    double horizontalPadding = 10,
    double verticalPadding = 8,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(width: 28, height: 28, borderRadius: 8),
          SizedBox(height: 5),
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 48, height: 10, borderRadius: 4),
            ),
          ),
          SizedBox(height: 2),
          SkeletonBox(width: 30, height: 16, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    Key? key,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double horizontalPadding = 10,
    double verticalPadding = 8,
    double titleFontSize = 11,
    double valueFontSize = 16,
  }) {
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, color: color, size: 16)),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
