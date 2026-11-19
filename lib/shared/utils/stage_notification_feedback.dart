import 'package:material_ui/material_ui.dart';
import 'package:remixicon/remixicon.dart';

import '../models/lead_status_update_result.dart';

class _ChannelNotice {
  const _ChannelNotice({
    required this.label,
    required this.status,
    required this.detail,
    required this.color,
    required this.icon,
    this.templateName,
    this.configurationStatus,
  });

  final String label;
  final String status;
  final String detail;
  final Color color;
  final IconData icon;
  final String? templateName;
  final String? configurationStatus;
}

String? _visibleDeliveryKey;
OverlayEntry? _visibleDeliveryEntry;

String _upper(dynamic value) => (value ?? '').toString().trim().toUpperCase();

String _blob(Map<String, dynamic> payload) {
  return [
        payload['reason'],
        payload['errorCode'],
        payload['error'],
        payload['message'],
        payload['details'],
      ]
      .whereType<Object>()
      .map((value) => value.toString())
      .join(' ')
      .toLowerCase();
}

bool _isLanguageProblem(Map<String, dynamic> payload, String blob) {
  final reason = _upper(payload['reason'] ?? payload['errorCode']);
  return reason.contains('LANGUAGE') ||
      blob.contains('language mismatch') ||
      blob.contains('language is unavailable');
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
  return reason.contains('CUSTOMER_EMAIL_MISSING') ||
      reason.contains('NO_EMAIL') ||
      blob.contains('email is missing') ||
      blob.contains('email address is missing');
}

_ChannelNotice _styleFor(String label, String status, String detail) {
  switch (status) {
    case 'SENT':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFF16A34A),
        icon: Remix.checkbox_circle_fill,
      );
    case 'DELIVERED':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFF16A34A),
        icon: Remix.mail_check_fill,
      );
    case 'READ':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFF16A34A),
        icon: Remix.eye_fill,
      );
    case 'FAILED':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFFDC2626),
        icon: Remix.error_warning_fill,
      );
    case 'PENDING':
    case 'QUEUED':
    case 'PROCESSING':
    case 'PENDING_APPROVAL':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFFD97706),
        icon: Remix.time_fill,
      );
    case 'NOT_CONFIGURED':
    case 'INACTIVE':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFFD97706),
        icon: Remix.information_fill,
      );
    case 'REJECTED':
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFFDC2626),
        icon: Remix.error_warning_fill,
      );
    default:
      return _ChannelNotice(
        label: label,
        status: status,
        detail: detail,
        color: const Color(0xFF64748B),
        icon: Remix.information_fill,
      );
  }
}

_ChannelNotice? _notice(String label, Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final status = _upper(payload['status']).isEmpty
      ? 'UNKNOWN'
      : _upper(payload['status']);
  final blob = _blob(payload);
  final whatsapp = label == 'WhatsApp';
  final templateName = payload['templateName']?.toString().trim();
  final configurationStatus = _upper(payload['configurationStatus']);

  _ChannelNotice notice(String status, String detail) => _ChannelNotice(
    label: label,
    status: status,
    detail: detail,
    color: _styleFor(label, status, detail).color,
    icon: _styleFor(label, status, detail).icon,
    templateName: templateName?.isEmpty == true ? null : templateName,
    configurationStatus: configurationStatus.isEmpty
        ? null
        : configurationStatus,
  );

  if (configurationStatus == 'NOT_CONFIGURED' || status == 'NOT_CONFIGURED') {
    return notice(
      'NOT_CONFIGURED',
      'No template is mapped to this stage for this channel.',
    );
  }
  if (configurationStatus == 'PENDING_APPROVAL' ||
      status == 'PENDING_APPROVAL') {
    return notice(
      'PENDING_APPROVAL',
      'The mapped WhatsApp template is awaiting Meta approval.',
    );
  }
  if (configurationStatus == 'REJECTED' || status == 'REJECTED') {
    return notice('REJECTED', 'Meta rejected the mapped WhatsApp template.');
  }
  if (configurationStatus == 'INACTIVE' || status == 'INACTIVE') {
    return notice(
      'INACTIVE',
      'The mapped template or stage automation is inactive.',
    );
  }
  if (status == 'QUEUED' || status == 'PROCESSING') {
    return notice(
      status,
      status == 'QUEUED'
          ? 'Mapped template is queued for delivery.'
          : 'Mapped template is being sent.',
    );
  }

  if (whatsapp && _isLanguageProblem(payload, blob)) {
    return notice('FAILED', 'Selected template language is unavailable.');
  }
  if (whatsapp && _isMissingTemplate(payload, blob)) {
    return notice('FAILED', 'Template not found or not approved.');
  }
  if (_isNotConfigured(payload, blob)) {
    return notice(
      'NOT_CONFIGURED',
      'No template is mapped to this stage for this channel.',
    );
  }
  if (!whatsapp && _isMissingEmail(payload, blob)) {
    return notice('SKIPPED', 'Customer email address is missing.');
  }
  if (status == 'SKIPPED') {
    final disabled = blob.contains('disabled') || blob.contains('inactive');
    return notice(
      'SKIPPED',
      disabled
          ? 'Stage or channel automation is disabled.'
          : 'Delivery was skipped.',
    );
  }

  switch (status) {
    case 'SENT':
      return notice(
        status,
        whatsapp ? 'Message sent successfully.' : 'Email sent successfully.',
      );
    case 'DELIVERED':
      return notice(
        status,
        whatsapp ? 'Message delivered.' : 'Email delivered.',
      );
    case 'READ':
      return notice(status, 'Message read.');
    case 'FAILED':
      return notice(
        status,
        whatsapp
            ? 'Message could not be sent. Please try again.'
            : 'Unable to send email. Please try again.',
      );
    case 'PENDING':
      return notice(status, 'Waiting to send.');
    default:
      return notice('FAILED', 'Something went wrong. Please try again.');
  }
}

bool _bothUnconfigured(_ChannelNotice? email, _ChannelNotice? whatsapp) {
  if (email == null || whatsapp == null) return false;
  return email.status == 'SKIPPED' &&
      whatsapp.status == 'SKIPPED' &&
      email.detail == 'No template configured for this stage.' &&
      whatsapp.detail == 'No template configured for this stage.';
}

void showStageAutomationFeedback(
  BuildContext context,
  LeadStatusUpdateResult result,
) {
  showStageChannelFeedback(
    context,
    email: result.emailNotification,
    whatsapp: result.whatsappNotification,
    stageId: result.lead.stageId,
    stageName: result.lead.stageName,
  );
}

void showStageChannelFeedback(
  BuildContext context, {
  Map<String, dynamic>? email,
  Map<String, dynamic>? whatsapp,
  Object? stageId,
  String? stageName,
}) {
  final emailNotice = _notice('Email', email);
  final whatsappNotice = _notice('WhatsApp', whatsapp);
  if (emailNotice == null && whatsappNotice == null) return;

  final bothSkipped = _bothUnconfigured(emailNotice, whatsappNotice);
  final key =
      '${stageId ?? 'unknown'}:${stageName ?? ''}|${bothSkipped ? 'both-skipped' : '${whatsappNotice?.status}:${whatsappNotice?.detail}:${whatsappNotice?.templateName}|${emailNotice?.status}:${emailNotice?.detail}:${emailNotice?.templateName}'}';
  if (_visibleDeliveryKey == key) return;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _visibleDeliveryEntry?.remove();
  _visibleDeliveryEntry = null;
  _visibleDeliveryKey = key;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _DeliveryNotice(
      notices: bothSkipped ? const [] : [?whatsappNotice, ?emailNotice],
      summary: bothSkipped
          ? 'Messages skipped: No channel is configured for this stage.'
          : null,
      stageName: stageName,
      onDismiss: () {
        if (_visibleDeliveryKey == key) {
          _visibleDeliveryKey = null;
          _visibleDeliveryEntry = null;
        }
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _visibleDeliveryEntry = entry;
  overlay.insert(entry);
}

class _DeliveryNotice extends StatefulWidget {
  const _DeliveryNotice({
    required this.notices,
    required this.onDismiss,
    this.summary,
    this.stageName,
  });

  final List<_ChannelNotice> notices;
  final String? summary;
  final String? stageName;
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onDismiss,
                        icon: const Icon(
                          Remix.close_line,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  if (widget.summary != null)
                    Text(
                      widget.summary!,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  if (widget.stageName?.trim().isNotEmpty == true)
                    Text(
                      'Stage: ${widget.stageName}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  for (final notice in widget.notices) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(notice.icon, color: notice.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${notice.label}: ${notice.status} – ${notice.detail}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              if (notice.templateName != null ||
                                  notice.configurationStatus != null)
                                Text(
                                  [
                                    if (notice.templateName != null)
                                      'Template: ${notice.templateName}',
                                    if (notice.configurationStatus != null)
                                      'Configuration: ${notice.configurationStatus}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                            ],
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
