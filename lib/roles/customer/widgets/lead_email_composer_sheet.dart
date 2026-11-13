import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';

class LeadEmailComposerSheet extends ConsumerStatefulWidget {
  final LeadModel lead;
  final VoidCallback? onSent;

  const LeadEmailComposerSheet({super.key, required this.lead, this.onSent});

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
        child: LeadEmailComposerSheet(lead: lead, onSent: onSent),
      ),
    );
  }

  @override
  ConsumerState<LeadEmailComposerSheet> createState() =>
      _LeadEmailComposerSheetState();
}

class _LeadEmailComposerSheetState
    extends ConsumerState<LeadEmailComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectController;
  late TextEditingController _messageController;
  bool _isCustom = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final leadName =
        (widget.lead.companyName != null && widget.lead.companyName!.isNotEmpty)
        ? widget.lead.companyName!
        : (widget.lead.firstName.isNotEmpty
              ? '${widget.lead.firstName} ${widget.lead.lastName}'.trim()
              : widget.lead.title);
    final stageName = widget.lead.stageNameConfig ?? widget.lead.status;
    _subjectController = TextEditingController(
      text: 'Lead Update - $stageName ($leadName)',
    );
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final email = widget.lead.email?.trim();
    if (email == null || email.isEmpty) {
      AppToast.error(context, 'Lead has no email address configured.');
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
            .sendLeadEmail(
              widget.lead.id,
              subject: _subjectController.text.trim(),
              message: _messageController.text.trim(),
            );
      } else {
        await ref.read(leadsProvider.notifier).sendLeadEmail(widget.lead.id);
      }

      if (mounted) {
        AppToast.success(context, 'Email dispatched successfully to $email');
        Navigator.pop(context);
        widget.onSent?.call();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          'Failed to send email: ${e.toString().replaceAll('Exception: ', '')}',
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
    final email = widget.lead.email?.trim() ?? '';
    final hasEmail = email.isNotEmpty;

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
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Remix.mail_send_line,
                        color: Color(0xFF4F46E5),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Email to Lead',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            hasEmail ? email : 'No email address registered',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: hasEmail
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

                // Mode Switcher: Stage Template vs Custom Email
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Lead Details Card',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        selected: !_isCustom,
                        selectedColor: const Color(
                          0xFF4F46E5,
                        ).withValues(alpha: 0.15),
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
                          0xFF4F46E5,
                        ).withValues(alpha: 0.15),
                        onSelected: (val) => setState(() => _isCustom = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_isCustom) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Remix.information_line,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Branded HTML Template',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sends a beautifully styled HTML email summary containing full registered contact information, stage, deal value, and your organization logo directly via configured SMTP.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: const Icon(Remix.text, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Subject is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Email Body',
                      alignLabelWithHint: true,
                      hintText: 'Type your update or proposal note here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message body is required'
                        : null,
                  ),
                ],

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (!hasEmail || _isSending) ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Remix.send_plane_2_fill, size: 18),
                  label: Text(
                    _isSending
                        ? 'Sending Email...'
                        : (_isCustom
                              ? 'Send Custom Email'
                              : 'Send Lead Details Email'),
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
