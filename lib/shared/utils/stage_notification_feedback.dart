import 'package:material_ui/material_ui.dart';
import 'package:remixicon/remixicon.dart';

import '../models/lead_status_update_result.dart';

class _ChannelNotice {
  const _ChannelNotice({required this.label, required this.status, required this.detail, required this.color, required this.icon});

  final String label;
  final String status;
  final String detail;
  final Color color;
  final IconData icon;
}

String? _visibleDeliveryKey;

String _upper(dynamic value) => (value ?? '').toString().trim().toUpperCase();

String _blob(Map<String, dynamic> payload) {
  return [
    payload['reason'],
    payload['errorCode'],
    payload['error'],
    payload['message'],
    payload['details'],
  ].whereType<Object>().map((value) => value.toString()).join(' ').toLowerCase();
}

bool _isLanguageProblem(Map<String, dynamic> payload, String blob) {
  final reason = _upper(payload['reason'] ?? payload['errorCode']);
  return reason.contains('LANGUAGE') || blob.contains('language mismatch') || blob.contains('language is unavailable');
}

bool _isMissingTemplate(Map<String, dynamic> payload, String blob) {
  final reason = _upper(payload['reason'] ?? payload['errorCode']);
  final meta = payload['metaErrorCode'];
  return meta == 132001 ||
      meta == '132001' ||
      reason.contains('TEMPLATE_NOT') ||
      reason.contains('TEMPLATE_PENDING') ||
      reason.contains('TEMPLATE_REJECT') ||
      reason.contains('132001') ||
      blob.contains('132001') ||
      blob.contains('not approved') ||
      blob.contains('does not exist');
}

bool _isNotConfigured(Map<String, dynamic> payload, String blob) {
  final reason = _upper(payload['reason'] ?? payload['errorCode']);
  return reason.contains('NOT_CONFIGURED') ||
      reason.contains('NO_TEMPLATE') ||
      reason.contains('EMAIL_TEMPLATE_MISSING') ||
      blob.contains('not configured') ||
      blob.contains('no template') ||
      blob.contains('no email template');
}

bool _isMissingEmail(Map<String, dynamic> payload, String blob) {
  final reason = _upper(payload['reason'] ?? payload['errorCode']);
  return reason.contains('CUSTOMER_EMAIL_MISSING') || reason.contains('NO_EMAIL') || blob.contains('email is missing') || blob.contains('email address is missing');
}

_ChannelNotice _styleFor(String label, String status, String detail) {
  switch (status) {
    case 'SENT':
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFF16A34A), icon: Remix.checkbox_circle_fill);
    case 'DELIVERED':
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFF16A34A), icon: Remix.mail_check_fill);
    case 'READ':
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFF16A34A), icon: Remix.eye_fill);
    case 'FAILED':
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFFDC2626), icon: Remix.error_warning_fill);
    case 'PENDING':
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFFD97706), icon: Remix.time_fill);
    default:
      return _ChannelNotice(label: label, status: status, detail: detail, color: const Color(0xFF64748B), icon: Remix.information_fill);
  }
}

_ChannelNotice? _notice(String label, Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final status = _upper(payload['status']).isEmpty ? 'UNKNOWN' : _upper(payload['status']);
  final blob = _blob(payload);
  final whatsapp = label == 'WhatsApp';

  if (whatsapp && _isLanguageProblem(payload, blob)) {
    return _styleFor(label, 'FAILED', 'Selected template language is unavailable.');
  }
  if (whatsapp && _isMissingTemplate(payload, blob)) {
    return _styleFor(label, 'FAILED', 'Template not found or not approved.');
  }
  if (_isNotConfigured(payload, blob)) {
    return _styleFor(label, 'SKIPPED', 'No template configured for this stage.');
  }
  if (whatsapp && status == 'SKIPPED') {
    return _styleFor(label, 'SKIPPED', 'No template configured for this stage.');
  }
  if (!whatsapp && _isMissingEmail(payload, blob)) {
    return _styleFor(label, 'SKIPPED', 'Customer email address is missing.');
  }
  if (!whatsapp && status == 'SKIPPED') {
    return _styleFor(label, 'SKIPPED', 'No template configured for this stage.');
  }

  switch (status) {
    case 'SENT':
      return _styleFor(label, status, whatsapp ? 'Message sent successfully.' : 'Email sent successfully.');
    case 'DELIVERED':
      return _styleFor(label, status, whatsapp ? 'Message delivered.' : 'Email delivered.');
    case 'READ':
      return _styleFor(label, status, 'Message read.');
    case 'FAILED':
      return _styleFor(label, status, whatsapp ? 'Message could not be sent. Please try again.' : 'Unable to send email. Please try again.');
    case 'PENDING':
      return _styleFor(label, status, 'Waiting to send.');
    default:
      return _styleFor(label, 'FAILED', 'Something went wrong. Please try again.');
  }
}

bool _bothUnconfigured(_ChannelNotice? email, _ChannelNotice? whatsapp) {
  if (email == null || whatsapp == null) return false;
  return email.status == 'SKIPPED' &&
      whatsapp.status == 'SKIPPED' &&
      email.detail == 'No template configured for this stage.' &&
      whatsapp.detail == 'No template configured for this stage.';
}

void showStageAutomationFeedback(BuildContext context, LeadStatusUpdateResult result) {
  showStageChannelFeedback(context, email: result.emailNotification, whatsapp: result.whatsappNotification);
}

void showStageChannelFeedback(
  BuildContext context, {
  Map<String, dynamic>? email,
  Map<String, dynamic>? whatsapp,
}) {
  final emailNotice = _notice('Email', email);
  final whatsappNotice = _notice('WhatsApp', whatsapp);
  if (emailNotice == null && whatsappNotice == null) return;

  final bothSkipped = _bothUnconfigured(emailNotice, whatsappNotice);
  final key = bothSkipped
      ? 'both-skipped'
      : '${whatsappNotice?.status}:${whatsappNotice?.detail}|${emailNotice?.status}:${emailNotice?.detail}';
  if (_visibleDeliveryKey == key) return;
  _visibleDeliveryKey = key;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _DeliveryNotice(
      notices: bothSkipped ? const [] : [?whatsappNotice, ?emailNotice],
      summary: bothSkipped ? 'Messages skipped: No channel is configured for this stage.' : null,
      onDismiss: () {
        if (_visibleDeliveryKey == key) _visibleDeliveryKey = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _DeliveryNotice extends StatefulWidget {
  const _DeliveryNotice({required this.notices, required this.onDismiss, this.summary});

  final List<_ChannelNotice> notices;
  final String? summary;
  final VoidCallback onDismiss;

  @override
  State<_DeliveryNotice> createState() => _DeliveryNoticeState();
}

class _DeliveryNoticeState extends State<_DeliveryNotice> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width < 420 ? width - 32 : 420),
          child: Material(
            color: const Color(0xFF0F172A),
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Message Delivery',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onDismiss,
                        icon: const Icon(Remix.close_line, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                  if (widget.summary != null)
                    Text(widget.summary!, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.35)),
                  for (final notice in widget.notices) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(notice.icon, color: notice.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${notice.label}: ${notice.status} – ${notice.detail}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
