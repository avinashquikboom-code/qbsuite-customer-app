import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';
import 'package:quickboom_crm_customer/shared/services/data_capture_service.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/data_capture/result_business_card.dart';

class DataCaptureResultsScreen extends ConsumerStatefulWidget {
  final ExtractionJobRecord jobRecord;
  final List<CapturedBusiness> places;

  const DataCaptureResultsScreen({
    super.key,
    required this.jobRecord,
    required this.places,
  });

  @override
  ConsumerState<DataCaptureResultsScreen> createState() =>
      _DataCaptureResultsScreenState();
}

class _DataCaptureResultsScreenState
    extends ConsumerState<DataCaptureResultsScreen> {
  final DataCaptureService _service = DataCaptureService();
  late List<CapturedBusiness> _places;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _places = List.from(widget.places);
  }

  int get _selectedCount => _places.where((p) => p.isSelected).length;

  void _selectAll(bool select) {
    setState(() {
      for (var p in _places) {
        p.isSelected = select;
      }
    });
  }

  Future<void> _importSelected() async {
    if (_isImporting) return;

    final selectedPlaces = _places.where((p) => p.isSelected).toList();
    if (selectedPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one business to import.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final selectedIds = selectedPlaces
          .map((p) => p.id?.toString() ?? p.googlePlaceId)
          .where((id) => id.isNotEmpty)
          .toList();

      final summary = await _service.importToLeads(
        jobId: widget.jobRecord.jobId,
        placeIds: selectedIds,
        places: selectedPlaces,
      );

      if (!mounted) return;

      // Mark imported places locally so cards update immediately
      setState(() {
        for (final place in _places) {
          if (!place.isSelected) continue;

          // Check if per-record results identify whether this place imported or was duplicate
          ImportedRecordResult? matchRecord;
          if (summary.records.isNotEmpty) {
            matchRecord = summary.records.firstWhere(
              (r) =>
                  (r.googlePlaceId != null &&
                      r.googlePlaceId!.isNotEmpty &&
                      r.googlePlaceId == place.googlePlaceId) ||
                  (r.sourceRecordId != null &&
                      r.sourceRecordId!.isNotEmpty &&
                      r.sourceRecordId == place.googlePlaceId) ||
                  (r.businessName.isNotEmpty &&
                      r.businessName.toLowerCase() ==
                          place.businessName.toLowerCase()),
              orElse: () => const ImportedRecordResult(
                sourceRecordId: '',
                businessName: '',
                imported: false,
                duplicate: false,
              ),
            );
          }

          if (matchRecord != null && matchRecord.businessName.isNotEmpty) {
            if (matchRecord.imported) {
              place.isImported = true;
              place.isSelected = false;
            }
          } else if (!summary.duplicateNames.contains(place.businessName)) {
            place.isImported = true;
            place.isSelected = false;
          }
        }
      });

      // Instantly refresh Leads pipeline provider so imported or duplicate leads appear without restart
      if (summary.imported > 0 ||
          summary.skippedDuplicates > 0 ||
          summary.records.any((r) => r.imported || r.duplicate)) {
        ref.read(leadsProvider.notifier).prefetchAfterImport();
        unawaited(ref.read(leadStagesProvider.notifier).refresh());
      }

      setState(() => _isImporting = false);

      final allDuplicates =
          summary.imported == 0 && summary.skippedDuplicates > 0;
      final isPartial = summary.imported > 0 && summary.skippedDuplicates > 0;

      final dialogTitle = allDuplicates
          ? 'Already in CRM'
          : isPartial
          ? 'Import Complete (Partial Duplicates)'
          : 'Import Complete';

      final dialogDescription = allDuplicates
          ? 'All selected businesses already exist in your CRM Leads pipeline.'
          : isPartial
          ? '${summary.imported} new businesses were imported to Leads. ${summary.skippedDuplicates} duplicate records already in CRM were skipped.'
          : 'All ${summary.imported} selected businesses were successfully imported to your CRM Leads pipeline.';

      // Show Import Result Dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: allDuplicates
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : isPartial
                      ? AppColors.info.withValues(alpha: 0.12)
                      : AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allDuplicates
                      ? Icons.copy_rounded
                      : isPartial
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_rounded,
                  color: allDuplicates
                      ? AppColors.warning
                      : isPartial
                      ? AppColors.info
                      : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  dialogTitle,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogDescription,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildResultRow(
                'Imported to Leads',
                '${summary.imported}',
                AppColors.primary,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                'Duplicates Skipped',
                '${summary.skippedDuplicates}',
                AppColors.warning,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  if (summary.imported > 0 && mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const DashboardView(initialTabIndex: 2),
                      ),
                      (route) => false,
                    );
                  } else if (context.mounted && Navigator.canPop(context)) {
                    Navigator.pop(context, summary.imported > 0);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: allDuplicates
                      ? AppColors.warning
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (err) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPadding = isWide ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppBarTitles.captureResults),
      body: Column(
        children: [
          // Query Overview Card
          Container(
            margin: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${widget.jobRecord.keyword} in ${widget.jobRecord.location}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Captured: ${_places.length} (Requested: ${widget.jobRecord.requestedResults})',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_selectedCount Selected',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selection Toolbar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Verified Prospects (${_places.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    InkWell(
                      onTap: () => _selectAll(true),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          'Select All',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _selectAll(false),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          'Deselect All',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List of Cards
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 6),
              physics: const BouncingScrollPhysics(),
              itemCount: _places.length,
              itemBuilder: (ctx, idx) {
                final place = _places[idx];
                return ResultBusinessCard(
                  business: place,
                  onToggleSelect: (val) {
                    setState(() {
                      place.isSelected = val ?? false;
                    });
                  },
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              hPadding,
              14,
              hPadding,
              MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isImporting || _selectedCount == 0
                    ? null
                    : _importSelected,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isImporting
                        ? 'Importing into CRM Leads...'
                        : 'Import Selected ($_selectedCount) to Leads',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
