import 'package:flutter/material.dart';

import '../../core/utils/app_toast.dart';
import '../models/lead_status_update_result.dart';

String _channelLine(String label, Map<String, dynamic>? payload) {
  if (payload == null) return '$label: no automation response';
  final status = (payload['status'] ?? payload['providerStatus'] ?? 'UNKNOWN').toString().toUpperCase();
  final message = (payload['message'] ?? payload['error'] ?? '').toString().trim();
  if (message.isEmpty) return '$label: $status';
  return '$label: $status — $message';
}

/// Shows automation delivery separately from the stage save toast (never claims DELIVERED from queue-only).
void showStageAutomationFeedback(BuildContext context, LeadStatusUpdateResult result) {
  showStageChannelFeedback(context, email: result.emailNotification, whatsapp: result.whatsappNotification);
}

void showStageChannelFeedback(
  BuildContext context, {
  Map<String, dynamic>? email,
  Map<String, dynamic>? whatsapp,
}) {
  if (email == null && whatsapp == null) return;

  final lines = <String>[
    if (email != null) _channelLine('Email', email),
    if (whatsapp != null) _channelLine('WhatsApp', whatsapp),
  ];

  final anyFailed = [email, whatsapp].whereType<Map<String, dynamic>>().any((p) {
    final s = (p['status'] ?? '').toString().toUpperCase();
    return s == 'FAILED';
  });
  final anySent = [email, whatsapp].whereType<Map<String, dynamic>>().any((p) {
    final s = (p['status'] ?? '').toString().toUpperCase();
    return s == 'SENT' || p['sent'] == true;
  });

  final body = lines.join('\n');
  if (anyFailed) {
    AppToast.warning(context, body);
  } else if (anySent) {
    AppToast.info(context, body);
  } else {
    AppToast.info(context, body);
  }
}
