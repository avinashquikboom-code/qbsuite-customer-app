import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/employee/views/visitor/visitor_complete_view.dart';

class VisitorRequirementView extends ConsumerStatefulWidget {
  final Map<String, dynamic> visit;
  final VoidCallback? onVisitUpdated;

  const VisitorRequirementView({
    super.key,
    required this.visit,
    this.onVisitUpdated,
  });

  @override
  ConsumerState<VisitorRequirementView> createState() =>
      _VisitorRequirementViewState();
}

class _VisitorRequirementViewState
    extends ConsumerState<VisitorRequirementView> {
  final _requirementController = TextEditingController();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherServiceController = TextEditingController();

  final List<String> _commonServices = [
    'E-commerce Website',
    'Social Media Marketing',
    'SEO (Optional)',
    'Website Development',
    'Mobile Application',
    'Other',
  ];

  final Set<String> _selectedServices = {};
  String _selectedBudget = '₹50,000 - ₹1,00,000';
  final List<String> _budgetOptions = [
    '< ₹50,000',
    '₹50,000 - ₹1,00,000',
    '₹1,00,000 - ₹2,50,000',
    '₹2,50,000+',
  ];

  String _selectedTimeline = 'Within 1 Month';
  final List<String> _timelines = [
    'Within 1 Month',
    '1 - 2 Months',
    'Immediate (1-2 weeks)',
    '3 - 6 Months',
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate if notes or purpose has info
    final purpose = widget.visit['purpose']?.toString() ?? '';
    if (purpose.isNotEmpty) {
      _requirementController.text = purpose;
    }
    _restoreServices();
  }

  @override
  void dispose() {
    _requirementController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    _otherServiceController.dispose();
    super.dispose();
  }

  String get _servicesValue {
    final names = _selectedServices.where((service) => service != 'Other').toList();
    if (_selectedServices.contains('Other')) names.add('Other: ${_otherServiceController.text.trim()}');
    return names.join(', ');
  }

  void _restoreServices() {
    final notes = widget.visit['notes']?.toString() ?? '';
    final lead = widget.visit['lead'];
    final category = lead is Map ? (lead['category']?.toString() ?? '') : '';
    final matches = RegExp(r'Required Services:\s*(.*)').allMatches(notes);
    final raw = matches.isEmpty ? category.trim() : matches.last.group(1)!.trim();
    if (raw.isEmpty) return;
    for (final part in raw.split(',')) {
      final item = part.trim();
      if (item.startsWith('Other:')) {
        _selectedServices.add('Other');
        _otherServiceController.text = item.substring(6).trim();
      } else if (_commonServices.contains(item)) {
        _selectedServices.add(item);
      }
    }
  }

  void _toggleService(String name, {bool other = false}) {
    setState(() {
      if (_selectedServices.contains(name)) {
        _selectedServices.remove(name);
        if (other) _otherServiceController.clear();
      } else {
        _selectedServices.add(name);
      }
    });
  }

  Widget _serviceCard(String name, IconData icon, {bool other = false}) {
    final on = _selectedServices.contains(name);
    return Semantics(
      button: true,
      checked: on,
      label: name,
      child: Material(
        color: on || other ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _toggleService(name, other: other),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? AppColors.primary : (other ? const Color(0xFFBBF7D0) : AppColors.borderLight), width: on ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2))),
                Icon(on ? Remix.checkbox_fill : Remix.checkbox_blank_line, color: on ? AppColors.primary : const Color(0xFFCBD5E1), size: 22),
              ]),
              if (other) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _otherServiceController,
                  enabled: on,
                  decoration: InputDecoration(
                    hintText: 'Please specify...',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFBBF7D0))),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveRequirement() async {
    final visitId = widget.visit['id'];
    if (visitId == null) return;

    final requirement = _requirementController.text.trim();
    if (requirement.isEmpty && _selectedServices.isEmpty) {
      AppToast.error(
        context,
        'Please specify requirement or select required services',
      );
      return;
    }
    if (_selectedServices.contains('Other') && _otherServiceController.text.trim().isEmpty) {
      AppToast.error(context, 'Please specify the other service.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final servicesStr = _servicesValue;
      final budgetStr = _selectedBudget;
      final notesStr = _notesController.text.trim();

      final res = await ref
          .read(apiClientProvider)
          .patch(
            '/mobile/visits/$visitId/requirement',
            data: {
              'requirement': requirement,
              'services': servicesStr,
              'budget': budgetStr,
              'timeline': _selectedTimeline,
              'notes': notesStr,
            },
          );

      Map<String, dynamic> updatedVisit = widget.visit;
      if (res.data != null && res.data is Map) {
        final raw = res.data['data'] is Map
            ? res.data['data']
            : (res.data['visit'] is Map ? res.data['visit'] : res.data);
        updatedVisit = Map<String, dynamic>.from(raw);
      }

      if (mounted) {
        AppToast.success(context, 'Requirement saved successfully!');
        widget.onVisitUpdated?.call();

        // Continue to Complete Visit flow
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitorCompleteView(
              visit: updatedVisit,
              requirementSummary: {
                'requirement': requirement,
                'services': servicesStr,
                'budget': budgetStr,
                'timeline': _selectedTimeline,
                'notes': notesStr,
              },
              onVisitUpdated: widget.onVisitUpdated,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to save requirement: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName =
        widget.visit['customer']?.toString() ??
        widget.visit['customerName']?.toString() ??
        'Client';

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
          'Customer Requirement',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Remix.user_star_fill,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          widget.visit['location']?.toString() ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Step 1 of 2',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: const [BoxShadow(color: Color(0x0A111827), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requirement Details *',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _requirementController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Client needs high-converting e-commerce web app & marketing campaign...',
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
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Required Services',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _serviceCard('E-commerce Website', Remix.shopping_bag_3_line)),
                    const SizedBox(width: 10),
                    Expanded(child: _serviceCard('Social Media Marketing', Remix.megaphone_line)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _serviceCard('SEO (Optional)', Remix.search_line)),
                    const SizedBox(width: 10),
                    Expanded(child: _serviceCard('Website Development', Remix.global_line)),
                  ]),
                  const SizedBox(height: 10),
                  _serviceCard('Mobile Application', Remix.smartphone_line),
                  const SizedBox(height: 10),
                  _serviceCard('Other', Remix.edit_2_line, other: true),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Budget (Approx.)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedBudget,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: _budgetOptions.map((b) {
                                return DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                    b,
                                    style: GoogleFonts.outfit(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBudget = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expected Timeline',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTimeline,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: _timelines.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: GoogleFonts.outfit(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedTimeline = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Additional Notes',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Client ne branding aur ad campaign bhi discuss kiya...',
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
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  const SizedBox(height: 14),

                  InkWell(
                    onTap: () {
                      AppToast.info(context, 'Photo attachment feature ready');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.camera_line,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Photos (Optional)',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSaving ? null : _handleSaveRequirement,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Remix.arrow_right_line, size: 20),
              label: Text(
                _isSaving ? 'SAVING...' : 'Save & Continue',
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
}
