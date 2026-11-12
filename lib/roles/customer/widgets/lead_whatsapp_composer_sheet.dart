import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_communication_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';

class LeadWhatsAppComposerSheet extends ConsumerStatefulWidget {
  final LeadModel lead;
  final VoidCallback? onSent;

  const LeadWhatsAppComposerSheet({super.key, required this.lead, this.onSent});

  static Future<void> show(
    BuildContext context,
    LeadModel lead, {
    VoidCallback? onSent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: LeadWhatsAppComposerSheet(lead: lead, onSent: onSent),
      ),
    );
  }

  @override
  ConsumerState<LeadWhatsAppComposerSheet> createState() =>
      _LeadWhatsAppComposerSheetState();
}

class _LeadWhatsAppComposerSheetState
    extends ConsumerState<LeadWhatsAppComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _messageController;
  WhatsAppTemplateModel? _selectedTemplate;
  bool _isCustom = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _renderTemplatePreview(String rawTemplate) {
    final leadName = (widget.lead.firstName.isNotEmpty)
        ? '${widget.lead.firstName} ${widget.lead.lastName}'.trim()
        : widget.lead.title;
    final stageName = widget.lead.stageNameConfig ?? widget.lead.status;
    return rawTemplate
        .replaceAll('{{leadName}}', leadName)
        .replaceAll('{{stage}}', stageName)
        .replaceAll('{{companyName}}', 'QuickBoom CRM')
        .replaceAll('{{userName}}', 'Account Representative');
  }

  Future<void> _handleSend() async {
    final phone = widget.lead.phone?.trim();
    if (phone == null || phone.isEmpty) {
      AppToast.error(context, 'Lead has no phone number registered.');
      return;
    }

    if (_isCustom && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_isCustom) {
        await ref
            .read(leadsProvider.notifier)
            .sendLeadWhatsApp(
              widget.lead.id,
              message: _messageController.text.trim(),
            );
      } else {
        await ref
            .read(leadsProvider.notifier)
            .sendLeadWhatsApp(
              widget.lead.id,
              templateName: _selectedTemplate?.templateName,
              stageName: widget.lead.stageNameConfig ?? widget.lead.status,
            );
      }

      if (mounted) {
        AppToast.success(context, 'WhatsApp message dispatched to $phone');
        Navigator.pop(context);
        widget.onSent?.call();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          'Failed to send WhatsApp: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.lead.phone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    final templatesAsync = ref.watch(whatsAppTemplatesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Remix.whatsapp_line,
                        color: Color(0xFF25D366),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send WhatsApp Message',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            hasPhone ? phone : 'No phone number registered',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: hasPhone
                                  ? AppColors.textSecondary
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Remix.close_line),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 18),

                // Mode Selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Stage Template',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        selected: !_isCustom,
                        selectedColor: const Color(
                          0xFF25D366,
                        ).withValues(alpha: 0.18),
                        onSelected: (val) => setState(() => _isCustom = !val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Custom Message',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        selected: _isCustom,
                        selectedColor: const Color(
                          0xFF25D366,
                        ).withValues(alpha: 0.18),
                        onSelected: (val) => setState(() => _isCustom = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_isCustom) ...[
                  templatesAsync.when(
                    data: (templates) {
                      if (templates.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Default stage template will be dispatched based on lead status "${widget.lead.stageNameConfig ?? widget.lead.status}".',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      // Auto-select template matching lead stage if not yet selected
                      if (_selectedTemplate == null) {
                        final currentStageKey =
                            (widget.lead.stageNameConfig ?? widget.lead.status)
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9]'), '');
                        for (final tpl in templates) {
                          final k = tpl.key.toLowerCase().replaceAll(
                            RegExp(r'[^a-z0-9]'),
                            '',
                          );
                          if (k.contains(currentStageKey) ||
                              currentStageKey.contains(k)) {
                            _selectedTemplate = tpl;
                            break;
                          }
                        }
                        _selectedTemplate ??= templates.first;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<WhatsAppTemplateModel>(
                            initialValue: _selectedTemplate,
                            decoration: InputDecoration(
                              labelText: 'Choose WhatsApp Template',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: templates.map((tpl) {
                              return DropdownMenuItem(
                                value: tpl,
                                child: Text(
                                  tpl.title,
                                  style: GoogleFonts.outfit(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedTemplate = val),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedTemplate != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF25D366,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF25D366,
                                  ).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Remix.chat_check_line,
                                        size: 16,
                                        color: Color(0xFF25D366),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Message Preview',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _renderTemplatePreview(
                                      _selectedTemplate!.body,
                                    ),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => Text(
                      'Default stage template will be automatically applied.',
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp Message',
                      alignLabelWithHint: true,
                      hintText:
                          'Type your WhatsApp message directly to prospect...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message is required'
                        : null,
                  ),
                ],

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (!hasPhone || _isSending) ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Remix.whatsapp_line, size: 18),
                  label: Text(
                    _isSending
                        ? 'Sending WhatsApp...'
                        : (_isCustom
                              ? 'Send Custom WhatsApp'
                              : 'Send WhatsApp Template'),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
