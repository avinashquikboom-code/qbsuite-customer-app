import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/lead_limit_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/views/lead_details_view.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';

void showNewLeadBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NewLeadBottomSheet(),
  );
}

Future<LeadModel?> showEditLeadBottomSheet(
  BuildContext context, {
  required LeadModel lead,
}) {
  return showModalBottomSheet<LeadModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NewLeadBottomSheet(initialLead: lead),
  );
}

class _NewLeadBottomSheet extends ConsumerStatefulWidget {
  final LeadModel? initialLead;
  const _NewLeadBottomSheet({this.initialLead});

  @override
  ConsumerState<_NewLeadBottomSheet> createState() =>
      _NewLeadBottomSheetState();
}

class _NewLeadBottomSheetState extends ConsumerState<_NewLeadBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final _leadNameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();

  String _selectedIndustry = 'Technology';
  String _selectedSource = 'Referral';
  // Stage is now loaded from Stage Management API, not hardcoded.
  LeadStageModel?
  _selectedStage; // null until stages load; auto-set to first active stage
  bool _isLoading = false;

  final List<String> _industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'Retail',
    'Other',
  ];
  final List<String> _sources = [
    'Referral',
    'Website',
    'Social Media',
    'Cold Call',
    'DATA_CAPTURE',
    'Other',
  ];
  bool get _isEdit => widget.initialLead != null;

  @override
  void initState() {
    super.initState();
    final lead = widget.initialLead;
    if (lead != null) {
      final name = '${lead.firstName} ${lead.lastName}'.trim();
      _leadNameCtrl.text = name.isNotEmpty ? name : lead.title;
      _companyNameCtrl.text =
          lead.companyName ?? (lead.title != name ? lead.title : '');
      _phoneCtrl.text = lead.phone ?? '';
      _emailCtrl.text = lead.email ?? '';
      _addressCtrl.text = lead.address ?? '';
      _cityCtrl.text = lead.city ?? '';
      _stateCtrl.text = lead.state ?? '';
      _pincodeCtrl.text = lead.pincode ?? '';
      _notesCtrl.text =
          lead.workNotes ??
          (lead.notes.isNotEmpty ? lead.notes.first.content : '');
      _websiteCtrl.text = lead.website ?? lead.socialMedia?.website ?? '';
      _instagramCtrl.text = lead.socialMedia?.instagram ?? '';
      _facebookCtrl.text = lead.socialMedia?.facebook ?? '';
      _linkedinCtrl.text = lead.socialMedia?.linkedin ?? '';
      if (lead.category != null && lead.category!.isNotEmpty) {
        if (!_industries.contains(lead.category)) {
          _industries.insert(0, lead.category!);
        }
        _selectedIndustry = lead.category!;
      }
      if (lead.source.isNotEmpty) {
        if (!_sources.contains(lead.source)) {
          _sources.insert(0, lead.source);
        }
        _selectedSource = lead.source;
      }
    }
  }

  @override
  void dispose() {
    _leadNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _notesCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _linkedinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Split name into first and last for the API
    final parts = _leadNameCtrl.text.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : (_isEdit ? '' : 'Contact');

    if (_isEdit) {
      final leadId = widget.initialLead!.id;
      try {
        final updatedLead = await ref.read(leadsProvider.notifier).updateLead(
          leadId,
          {
            'title': _companyNameCtrl.text.trim().isNotEmpty
                ? _companyNameCtrl.text.trim()
                : _leadNameCtrl.text.trim(),
            'firstName': firstName,
            'lastName': lastName,
            'companyName': _companyNameCtrl.text.trim().isNotEmpty
                ? _companyNameCtrl.text.trim()
                : null,
            'phone': _phoneCtrl.text.trim().isNotEmpty
                ? _phoneCtrl.text.trim()
                : null,
            'email': _emailCtrl.text.trim().isNotEmpty
                ? _emailCtrl.text.trim()
                : null,
            'address': _addressCtrl.text.trim().isNotEmpty
                ? _addressCtrl.text.trim()
                : null,
            'city': _cityCtrl.text.trim().isNotEmpty
                ? _cityCtrl.text.trim()
                : null,
            'state': _stateCtrl.text.trim().isNotEmpty
                ? _stateCtrl.text.trim()
                : null,
            'pincode': _pincodeCtrl.text.trim().isNotEmpty
                ? _pincodeCtrl.text.trim()
                : null,
            'workNotes': _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : null,
            'category': _selectedIndustry,
            'source': _selectedSource,
            'website': _websiteCtrl.text.trim().isNotEmpty
                ? _websiteCtrl.text.trim()
                : null,
            'socialMedia': {
              if (_instagramCtrl.text.trim().isNotEmpty)
                'instagram': _instagramCtrl.text.trim(),
              if (_facebookCtrl.text.trim().isNotEmpty)
                'facebook': _facebookCtrl.text.trim(),
              if (_linkedinCtrl.text.trim().isNotEmpty)
                'linkedin': _linkedinCtrl.text.trim(),
              if (_websiteCtrl.text.trim().isNotEmpty)
                'website': _websiteCtrl.text.trim(),
            },
            if (_instagramCtrl.text.trim().isNotEmpty)
              'instagram': _instagramCtrl.text.trim(),
            if (_facebookCtrl.text.trim().isNotEmpty)
              'facebook': _facebookCtrl.text.trim(),
            if (_linkedinCtrl.text.trim().isNotEmpty)
              'linkedin': _linkedinCtrl.text.trim(),
            if (_selectedStage != null && _selectedStage!.id.toString() != widget.initialLead!.stageId) ...{
              'stageId': _selectedStage!.id,
              'status': _selectedStage!.key,
            },
          },
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (updatedLead != null) {
            AppToast.success(context, 'Lead Updated Successfully!');
            Navigator.pop(context, updatedLead);
          } else {
            AppToast.error(context, 'Failed to update lead.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          final rawMsg = e.toString();
          final cleanMsg = rawMsg.startsWith('Exception: ')
              ? rawMsg.substring(11)
              : rawMsg;
          AppToast.error(context, cleanMsg);
        }
      }
      return;
    }

    try {
      final createdLead = await ref.read(leadsProvider.notifier).createLead({
        'title': _companyNameCtrl.text.isNotEmpty
            ? _companyNameCtrl.text.trim()
            : _leadNameCtrl.text.trim(),
        'firstName': firstName,
        'lastName': lastName,
        'companyName': _companyNameCtrl.text.trim().isNotEmpty
            ? _companyNameCtrl.text.trim()
            : null,
        'phone': _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : null,
        'email': _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
        'address': _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : null,
        'city': _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
        'state': _stateCtrl.text.trim().isNotEmpty
            ? _stateCtrl.text.trim()
            : null,
        'pincode': _pincodeCtrl.text.trim().isNotEmpty
            ? _pincodeCtrl.text.trim()
            : null,
        'workNotes': _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        'category': _selectedIndustry,
        'value': 0.0,
        'website': _websiteCtrl.text.trim().isNotEmpty
            ? _websiteCtrl.text.trim()
            : null,
        'socialMedia': {
          if (_instagramCtrl.text.trim().isNotEmpty)
            'instagram': _instagramCtrl.text.trim(),
          if (_facebookCtrl.text.trim().isNotEmpty)
            'facebook': _facebookCtrl.text.trim(),
          if (_linkedinCtrl.text.trim().isNotEmpty)
            'linkedin': _linkedinCtrl.text.trim(),
          if (_websiteCtrl.text.trim().isNotEmpty)
            'website': _websiteCtrl.text.trim(),
        },
        if (_instagramCtrl.text.trim().isNotEmpty)
          'instagram': _instagramCtrl.text.trim(),
        if (_facebookCtrl.text.trim().isNotEmpty)
          'facebook': _facebookCtrl.text.trim(),
        if (_linkedinCtrl.text.trim().isNotEmpty)
          'linkedin': _linkedinCtrl.text.trim(),
        'source': _selectedSource,
        // Send stageId from Stage Management API. Backend validates stage belongs to workspace.
        if (_selectedStage != null) 'stageId': _selectedStage!.id,
        if (_selectedStage != null) 'status': _selectedStage!.key,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (createdLead != null) {
          AppToast.success(context, 'Lead Created Successfully!');
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeadDetailsView(
                leadId: createdLead.id,
                initialLead: createdLead,
              ),
            ),
          );
        } else {
          AppToast.error(context, 'Failed to create lead.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final rawMsg = e.toString();
        final cleanMsg = rawMsg.startsWith('Exception: ')
            ? rawMsg.substring(11)
            : rawMsg;
        AppToast.error(context, cleanMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding for keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEdit ? 'Edit Lead' : 'New Lead',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Remix.close_line,
                          color: AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                // Scrollable Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: bottomInset > 0
                            ? bottomInset + 20
                            : 100, // Extra padding for button
                      ),
                      children: [
                        _buildSectionTitle('Lead Information'),
                        _buildTextField(
                          'Lead Name *',
                          _leadNameCtrl,
                          'e.g. John Doe',
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        _buildTextField(
                          'Company Name',
                          _companyNameCtrl,
                          'e.g. Acme Corp',
                        ),
                        _buildTextField(
                          'Phone Number',
                          _phoneCtrl,
                          '+91 0000000000',
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          'Email',
                          _emailCtrl,
                          'john@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 12),
                        _buildSectionTitle('Business Information'),
                        _buildDropdown(
                          'Industry',
                          _selectedIndustry,
                          _industries,
                          (v) => setState(() => _selectedIndustry = v!),
                        ),
                        _buildDropdown(
                          'Lead Source',
                          _selectedSource,
                          _sources,
                          (v) => setState(() => _selectedSource = v!),
                        ),

                        // Stage dropdown — loaded from Stage Management API
                        _buildApiStageDropdown(ref),

                        const SizedBox(height: 12),
                        _buildSectionTitle('Location'),
                        _buildTextField(
                          'Address',
                          _addressCtrl,
                          'Street Address',
                          maxLines: 2,
                        ),
                        _buildTextField('City', _cityCtrl, 'e.g. Mumbai'),
                        _buildTextField('State', _stateCtrl, 'e.g. Maharashtra'),
                        _buildTextField(
                          'Pincode',
                          _pincodeCtrl,
                          '000000',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 12),
                        _buildSectionTitle('Social Media & Web'),
                        _buildTextField(
                          'Website URL',
                          _websiteCtrl,
                          'https://company.com',
                          keyboardType: TextInputType.url,
                        ),
                        _buildTextField(
                          'Instagram',
                          _instagramCtrl,
                          'https://instagram.com/... or @handle',
                        ),
                        _buildTextField(
                          'Facebook',
                          _facebookCtrl,
                          'https://facebook.com/...',
                        ),
                        _buildTextField(
                          'LinkedIn',
                          _linkedinCtrl,
                          'https://linkedin.com/in/...',
                        ),

                        const SizedBox(height: 12),
                        _buildSectionTitle('Additional Information'),
                        _buildTextField(
                          'Notes',
                          _notesCtrl,
                          'Enter any additional details...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer / Button
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          final limitState = ref.watch(leadLimitProvider);
                          final isDailyExhausted =
                              limitState.value?.daily.isExhausted ?? false;
                          final isMonthlyExhausted =
                              limitState.value?.monthly.isExhausted ?? false;
                          final isLimitExhausted =
                              isDailyExhausted || isMonthlyExhausted;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isEdit && isLimitExhausted)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Remix.error_warning_fill,
                                        color: AppColors.error,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isDailyExhausted
                                            ? 'Daily lead generation limit reached.'
                                            : 'Monthly lead generation limit reached.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      (_isLoading ||
                                          (!_isEdit && isLimitExhausted))
                                      ? null
                                      : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        (!_isEdit && isLimitExhausted)
                                        ? Colors.grey
                                        : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          _isEdit
                                              ? 'SAVE CHANGES'
                                              : 'CREATE LEAD',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Stage dropdown loaded from Stage Management API.
  /// No hardcoded values — stages come from GET /leads/stages sorted by sortOrder.
  Widget _buildApiStageDropdown(WidgetRef ref) {
    final stagesAsync = ref.watch(leadStagesProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lead Stage',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          stagesAsync.when(
            loading: () => Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error),
              ),
              child: Center(
                child: Text(
                  'Failed to load stages',
                  style: GoogleFonts.outfit(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            data: (stages) {
              final activeStages = stages.where((s) => s.isActive).toList();
              // Auto-select stage if nothing selected
              if (_selectedStage == null && activeStages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedStage == null) {
                    final matchingStage = widget.initialLead != null
                        ? activeStages.cast<LeadStageModel?>().firstWhere(
                            (s) =>
                                s?.id.toString() ==
                                    widget.initialLead!.stageId ||
                                s?.key == widget.initialLead!.status,
                            orElse: () => null,
                          )
                        : null;
                    setState(
                      () =>
                          _selectedStage = matchingStage ?? activeStages.first,
                    );
                  }
                });
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LeadStageModel>(
                    value: activeStages.contains(_selectedStage)
                        ? _selectedStage
                        : null,
                    isExpanded: true,
                    hint: Text(
                      activeStages.isEmpty
                          ? 'No stages configured'
                          : 'Select stage',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    icon: const Icon(
                      Remix.arrow_down_s_line,
                      color: AppColors.textSecondary,
                    ),
                    items: activeStages.map((stage) {
                      return DropdownMenuItem<LeadStageModel>(
                        value: stage,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: stage.stageColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              stage.name,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (LeadStageModel? stage) {
                      if (stage != null) setState(() => _selectedStage = stage);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Remix.arrow_down_s_line,
                  color: AppColors.textSecondary,
                ),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
