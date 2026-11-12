import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/constants/app_bar_titles.dart';
import 'package:quickboom_crm_customer/shared/services/data_capture_service.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/shared/widgets/data_capture/business_type_selector.dart';
import 'package:quickboom_crm_customer/shared/widgets/data_capture/location_selector.dart';
import 'data_capture_records_screen.dart';

class NewDataCaptureScreen extends StatefulWidget {
  const NewDataCaptureScreen({super.key});

  @override
  State<NewDataCaptureScreen> createState() => _NewDataCaptureScreenState();
}

class _NewDataCaptureScreenState extends State<NewDataCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataCaptureService _service = DataCaptureService();

  String _selectedCategory = 'Gym';
  final TextEditingController _customKeywordCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController(
    text: 'Vadodara',
  );
  int _maxResults = 20;

  bool _isExtracting = false;
  String _extractionStep = 'Ready to capture';

  @override
  void dispose() {
    _customKeywordCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (_isExtracting) return;

    final location = _locationCtrl.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please specify a target city or locality.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final keyword = _selectedCategory == 'Custom Business'
        ? _customKeywordCtrl.text.trim()
        : _selectedCategory;

    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a custom business keyword or specialty.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isExtracting = true;
      _extractionStep = 'Searching businesses on Google Places...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(
        () => _extractionStep = 'Finding verified prospects in $location...',
      );

      final requestId = 'cap-${DateTime.now().millisecondsSinceEpoch}';
      final jobRecord = await _service.extractPlaces(
        keyword: keyword,
        location: location,
        maxResults: _maxResults,
        requestId: requestId,
      );

      if (!mounted) return;
      setState(() => _extractionStep = 'Processing results...');
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      setState(() => _isExtracting = false);

      // Navigate to Results Screen
      final imported = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DataCaptureRecordsScreen(jobId: jobRecord.jobId),
        ),
      );

      if (mounted && imported == true && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isExtracting = false);
        final friendlyMessage = _getFriendlyErrorMessage(err);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyMessage,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getFriendlyErrorMessage(dynamic err) {
    if (err is DioException) {
      if (err.type == DioExceptionType.receiveTimeout ||
          err.type == DioExceptionType.connectionTimeout ||
          err.type == DioExceptionType.sendTimeout) {
        return 'Data capture is taking longer than expected. Please try again.';
      }
      final statusCode = err.response?.statusCode;
      if (statusCode == 504) {
        return 'Google Places search timed out. Please try again with fewer results.';
      }
      if (statusCode == 429) {
        return 'Google Places API quota limit reached. Please try again later.';
      }
      final data = err.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'].toString();
        if (!msg.contains('Exception') &&
            !msg.contains('Error:') &&
            !msg.contains('Internal server') &&
            !msg.contains('stack') &&
            !msg.contains('DioException')) {
          return msg;
        }
      }
      if (err.type == DioExceptionType.connectionError) {
        return 'Unable to connect to server. Please check your internet connection.';
      }
    }
    final raw = err.toString();
    if (raw.toLowerCase().contains('timeout') ||
        raw.toLowerCase().contains('timed out')) {
      return 'Data capture is taking longer than expected. Please try again.';
    }
    return 'Data capture is taking longer than expected. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedCategory == 'Custom Business';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: AppBarTitles.newDataCapture),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a business type and location to extract live, verified Google Places prospects.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 1. Business Category
              _buildFieldLabel('Business Type / Category *'),
              BusinessTypeSelector(
                selectedCategory: _selectedCategory,
                onSelected: (val) {
                  setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 18),

              // 1.1 Custom Keyword if chosen
              if (isCustom) ...[
                _buildFieldLabel('Custom Business Keyword *'),
                TextFormField(
                  controller: _customKeywordCtrl,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Interior designers, Solar panel dealers, Chartered accountants',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textPlaceholder,
                    ),
                    prefixIcon: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 2. Target Location
              _buildFieldLabel('Target City / Locality *'),
              LocationSelector(
                controller: _locationCtrl,
                onLocationChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 22),

              // 3. Max Results
              _buildFieldLabel('Maximum Results to Capture'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [10, 20, 50, 60].map((count) {
                        final isSelected = _maxResults == count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _maxResults = count),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Google Places API returns up to 60 verified commercial places per query. Extractions will capture available records up to your selected maximum.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Extraction Status / Progress indicator
              if (_isExtracting) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capturing Business Prospects...',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _extractionStep,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isExtracting ? null : _startCapture,
                  icon: const Icon(Icons.travel_explore_rounded, size: 22),
                  label: Text(
                    _isExtracting ? 'Extracting...' : 'Start Capture',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
