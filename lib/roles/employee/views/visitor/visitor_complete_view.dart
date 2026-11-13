import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

class VisitorCompleteView extends ConsumerStatefulWidget {
  final Map<String, dynamic> visit;
  final Map<String, dynamic>? requirementSummary;
  final VoidCallback? onVisitUpdated;

  const VisitorCompleteView({
    super.key,
    required this.visit,
    this.requirementSummary,
    this.onVisitUpdated,
  });

  @override
  ConsumerState<VisitorCompleteView> createState() =>
      _VisitorCompleteViewState();
}

class _VisitorCompleteViewState extends ConsumerState<VisitorCompleteView> {
  final _remarksController = TextEditingController();
  String _selectedStatus = 'Interested';
  DateTime _nextFollowUpDate = DateTime.now().add(const Duration(days: 7));

  final List<String> _statusOptions = [
    'Interested',
    'Not Interested',
    'Follow-up Required',
  ];

  @override
  void initState() {
    super.initState();
    final prevNotes = widget.requirementSummary?['notes']?.toString();
    if (prevNotes != null && prevNotes.isNotEmpty) {
      _remarksController.text = prevNotes;
    } else {
      _remarksController.text =
          'Client interested hai. Further proposal bhejna hai.';
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _nextFollowUpDate = picked);
    }
  }

  void _onProceedToReview() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final customerName =
        widget.visit['customer']?.toString() ??
        widget.visit['customerName']?.toString() ??
        'Sharma Enterprises';
    final location = widget.visit['location']?.toString() ?? 'Delhi';
    final timeStr = widget.visit['time']?.toString() ?? '10:00 AM';
    final dateStr = widget.visit['date']?.toString() ?? '25 Sep 2025';

    final services =
        widget.requirementSummary?['services']?.toString() ??
        'E-commerce Website, Social Media Marketing';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Complete Visit',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visit Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visit Summary',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSummaryItem(
                    'Customer Name',
                    customerName,
                    isBold: true,
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryItem('Visit Date & Time', '$dateStr, $timeStr'),
                  const SizedBox(height: 10),
                  _buildSummaryItem('Location', location),
                  const SizedBox(height: 10),
                  _buildSummaryItem('Services', services),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 12),
                  Text(
                    'Remarks',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _remarksController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Client interested hai. Further proposal bhejna hai.',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textPlaceholder,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Visit Status Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visit Status',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusOptions.map((status) {
                      final isSelected = _selectedStatus == status;
                      Color activeColor = AppColors.primary;
                      if (status == 'Interested') {
                        activeColor = const Color(0xFF16A34A);
                      }
                      if (status == 'Not Interested') {
                        activeColor = const Color(0xFFDC2626);
                      }
                      if (status == 'Follow-up Required') {
                        activeColor = const Color(0xFFD97706);
                      }

                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(status),
                        labelStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        selectedColor: activeColor,
                        backgroundColor: AppColors.scaffoldBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? activeColor
                                : AppColors.borderLight,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatus = status);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            if (_selectedStatus != 'Not Interested') ...[
              const SizedBox(height: 18),

              // Next Follow-up Date
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Follow-up Date',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Remix.calendar_line,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatDate(_nextFollowUpDate),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Remix.arrow_down_s_line,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, -3),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _onProceedToReview,
              child: Text(
                'Complete Visit',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
