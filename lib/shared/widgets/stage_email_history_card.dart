import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';

class StageEmailHistoryCard extends ConsumerStatefulWidget {
  final String leadId;

  const StageEmailHistoryCard({super.key, required this.leadId});

  @override
  ConsumerState<StageEmailHistoryCard> createState() => _StageEmailHistoryCardState();
}

class _StageEmailHistoryCardState extends ConsumerState<StageEmailHistoryCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  int? _retryingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/leads/${widget.leadId}/stage-email/history');
      final raw = response.data;
      final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] as List : []);
      if (!mounted) return;
      setState(() {
        _rows = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry(int deliveryId) async {
    setState(() => _retryingId = deliveryId);
    try {
      await ref.read(apiClientProvider).post('/leads/${widget.leadId}/stage-email/$deliveryId/retry');
      if (mounted) AppToast.success(context, 'Email retry queued');
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, 'Retry failed');
    } finally {
      if (mounted) setState(() => _retryingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Remix.mail_line, color: Color(0xFF163A2E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stage automation (Email)',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(onPressed: _load, icon: const Icon(Remix.refresh_line, size: 20)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_rows.isEmpty)
              Text('No automated stage emails yet.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)))
            else
              ..._rows.take(8).map((row) {
                final status = (row['status'] ?? 'PENDING').toString().toUpperCase();
                final canRetry = status == 'FAILED' || status == 'SKIPPED';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['previousStage'] ?? '—'} → ${row['newStage'] ?? '—'}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${row['templateName'] ?? 'Template'} · ${row['recipientEmail'] ?? '—'}',
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text('Status: $status', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                          if ((row['providerMessageId'] ?? '').toString().isNotEmpty)
                            Text('Message ID: ${row['providerMessageId']}', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                          if ((row['error'] ?? '').toString().isNotEmpty)
                            Text(row['error'].toString(), style: GoogleFonts.outfit(fontSize: 11, color: Colors.red.shade700)),
                          if (canRetry)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _retryingId == row['id'] ? null : () => _retry(int.parse(row['id'].toString())),
                                child: Text(_retryingId == row['id'] ? 'Retrying…' : 'Retry'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
