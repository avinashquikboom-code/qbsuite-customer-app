import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';

class SendDetailsDeliveryHistoryCard extends ConsumerStatefulWidget {
  final String leadId;
  final VoidCallback onSendDetails;

  const SendDetailsDeliveryHistoryCard({
    super.key,
    required this.leadId,
    required this.onSendDetails,
  });

  @override
  ConsumerState<SendDetailsDeliveryHistoryCard> createState() => _SendDetailsDeliveryHistoryCardState();
}

class _SendDetailsDeliveryHistoryCardState extends ConsumerState<SendDetailsDeliveryHistoryCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _deliveries = [];
  int? _retryingId;
  final Set<String> _expandedErrorKeys = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await ref.read(apiClientProvider).get('/mobile/leads/${widget.leadId}/send-details/history');
      final raw = response.data;
      final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] as List : []);
      if (!mounted) return;
      setState(() {
        _deliveries = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _channelFailed(String status, String? error) {
    final normalized = status.toUpperCase();
    if (normalized == 'FAILED') return true;
    return (normalized == 'SKIPPED' || normalized == 'PENDING') && (error?.trim().isNotEmpty ?? false);
  }

  String? _channelError(Map<String, dynamic> item, String channel) {
    final statusKey = channel == 'WHATSAPP' ? 'whatsappStatus' : 'emailStatus';
    final errorKey = channel == 'WHATSAPP' ? 'whatsappError' : 'emailError';
    final resultKey = channel == 'WHATSAPP' ? 'whatsappResult' : 'emailResult';

    final status = item[statusKey]?.toString().toUpperCase() ?? 'SKIPPED';
    if (status == 'SENT' || status == 'DELIVERED' || status == 'READ') return null;

    final nested = item[resultKey];
    if (nested is Map && nested['error'] is String) {
      final nestedError = (nested['error'] as String).trim();
      if (nestedError.isNotEmpty) return nestedError;
    }

    final flatError = item[errorKey]?.toString().trim();
    if (flatError != null && flatError.isNotEmpty) return flatError;
    return null;
  }

  List<String> _extractMissingDocumentNames(String error) {
    final names = <String>[];
    final quoted = RegExp(r'Document "([^"]+)"');
    for (final match in quoted.allMatches(error)) {
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) names.add(value);
    }
    if (names.isNotEmpty) return names;

    final missingMatch = RegExp(r'Missing:\s*(.+?)(?:\.|$)').firstMatch(error);
    if (missingMatch != null) {
      return missingMatch
          .group(1)!
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
  return names;
  }

  String _errorSummary(String error) {
    final missing = _extractMissingDocumentNames(error);
    if (missing.isNotEmpty) {
      return 'Missing or invalid PDFs (${missing.length}): ${missing.take(2).join(', ')}${missing.length > 2 ? '…' : ''}';
    }
    if (error.length <= 96) return error;
    return '${error.substring(0, 93)}…';
  }

  Future<void> _retry(int deliveryId) async {
    setState(() => _retryingId = deliveryId);
    try {
      final response = await ref.read(apiClientProvider).post(
        '/mobile/leads/${widget.leadId}/send-details/$deliveryId/retry',
        data: {'channel': 'ALL'},
      );
      final raw = response.data;
      final data = raw is Map && raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});

      final overall = data['overallStatus']?.toString().toUpperCase() ?? '';
      final waStatus = data['whatsappStatus']?.toString().toUpperCase() ?? '';
      final emStatus = data['emailStatus']?.toString().toUpperCase() ?? '';
      final waFailed = _channelFailed(waStatus, _channelError(data, 'WHATSAPP'));
      final emFailed = _channelFailed(emStatus, _channelError(data, 'EMAIL'));

      if (mounted) {
        if (overall == 'FAILED' || waFailed || emFailed) {
          final failedParts = <String>[];
          if (waFailed) {
            final err = _channelError(data, 'WHATSAPP');
            if (err != null) failedParts.add('WhatsApp: ${_errorSummary(err)}');
          }
          if (emFailed) {
            final err = _channelError(data, 'EMAIL');
            if (err != null) failedParts.add('Email: ${_errorSummary(err)}');
          }
          AppToast.error(context, failedParts.isEmpty ? 'Retry did not deliver the package.' : failedParts.join(' '));
        } else if (overall == 'COMPLETED' || overall == 'SENT') {
          AppToast.success(context, 'Delivery completed');
        } else {
          AppToast.info(context, 'Retry finished with status $overall');
        }
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _retryingId = null);
    }
  }

  String _timeAgo(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Widget _channelRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String status,
    required String? error,
    required int deliveryId,
    required bool canRetryThisChannel,
  }) {
    final expandKey = '$deliveryId-$label';
    final normalized = status.toUpperCase();
    final showError = error != null && _channelFailed(normalized, error);
    final statusColor = normalized == 'SENT' || normalized == 'DELIVERED' || normalized == 'READ'
        ? const Color(0xFF16A34A)
        : (normalized == 'FAILED' ? const Color(0xFFDC2626) : const Color(0xFF64748B));
    final expanded = _expandedErrorKeys.contains(expandKey);
    final missing = showError ? _extractMissingDocumentNames(error) : <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                    children: [
                      TextSpan(text: '$label: '),
                      TextSpan(
                        text: normalized,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (showError) ...[
                  const SizedBox(height: 2),
                  Text(
                    _errorSummary(error),
                    maxLines: expanded ? null : 2,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFB45309), height: 1.3),
                  ),
                  if (error.length > 96 || missing.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (expanded) {
                            _expandedErrorKeys.remove(expandKey);
                          } else {
                            _expandedErrorKeys.add(expandKey);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          expanded ? 'Hide error details' : 'View error details',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                        ),
                      ),
                    ),
                  if (expanded && missing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ...missing.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (expanded && missing.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(error, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), height: 1.35)),
                    ),
                ],
              ],
            ),
          ),
          if (canRetryThisChannel && showError)
            InkWell(
              onTap: _retryingId == deliveryId ? null : () => _retry(deliveryId),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                child: _retryingId == deliveryId
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFDC2626)),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Remix.refresh_line, size: 12, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text('Retry', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final wide = width >= 720;
    double fs(double size) => size * (compact ? 0.92 : wide ? 1.06 : 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Remix.mail_send_fill, size: 16, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Send Details Package History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: fs(15),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Remix.refresh_line, size: 16, color: Color(0xFF64748B)),
                onPressed: _loadHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 44,
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_deliveries.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Remix.information_line, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No packages sent yet. Automatically sent on Details Sent stage or manual send.',
                      style: GoogleFonts.outfit(fontSize: fs(12), color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._deliveries.take(3).map((item) {
              final id = (item['id'] as num?)?.toInt() ?? 0;
              final overall = item['overallStatus']?.toString().toUpperCase() ?? 'PENDING';
              final waStatus = item['whatsappStatus']?.toString().toUpperCase() ?? 'SKIPPED';
              final emStatus = item['emailStatus']?.toString().toUpperCase() ?? 'SKIPPED';
              final trigger = item['triggerType']?.toString().toUpperCase() ?? 'AUTOMATIC';
              final timeStr = _timeAgo(item['createdAt']?.toString());
              final waError = _channelError(item, 'WHATSAPP');
              final emError = _channelError(item, 'EMAIL');
              final waFailed = _channelFailed(waStatus, waError);
              final emFailed = _channelFailed(emStatus, emError);

              Color overallColor;
              if (overall == 'SENT' || overall == 'COMPLETED') {
                overallColor = const Color(0xFF16A34A);
              } else if (overall == 'PARTIAL' || overall == 'PARTIALLY_COMPLETED') {
                overallColor = const Color(0xFFD97706);
              } else if (overall == 'PENDING' || overall == 'PROCESSING') {
                overallColor = const Color(0xFF64748B);
              } else {
                overallColor = const Color(0xFFDC2626);
              }

              final overallLabel = overall == 'PARTIALLY_COMPLETED' ? 'PARTIALLY COMPLETED' : overall;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trigger,
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: overallColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            overallLabel,
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: overallColor),
                          ),
                        ),
                        Text(timeStr, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _channelRow(
                      icon: Remix.whatsapp_fill,
                      iconColor: const Color(0xFF16A34A),
                      label: 'WhatsApp',
                      status: waStatus,
                      error: waError,
                      deliveryId: id,
                      canRetryThisChannel: waFailed && !emFailed,
                    ),
                    _channelRow(
                      icon: Remix.mail_fill,
                      iconColor: const Color(0xFF4F46E5),
                      label: 'Email',
                      status: emStatus,
                      error: emError,
                      deliveryId: id,
                      canRetryThisChannel: emFailed && !waFailed,
                    ),
                    if (waFailed && emFailed)
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: _retryingId == id ? null : () => _retry(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                            child: _retryingId == id
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFDC2626)),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Remix.refresh_line, size: 12, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text('Retry failed channels', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
