import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/models/lead_model.dart';

class SendDetailsSheet extends ConsumerStatefulWidget {
  final LeadModel lead;
  final VoidCallback? onDispatched;

  const SendDetailsSheet({super.key, required this.lead, this.onDispatched});

  @override
  ConsumerState<SendDetailsSheet> createState() => _SendDetailsSheetState();
}

class _SendDetailsSheetState extends ConsumerState<SendDetailsSheet> {
  static const _missingDocsHint =
      'Upload missing PDFs in Admin: Settings → CRM → Send Details → Company Documents.';

  bool _loadingDocs = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _documents = [];
  final Set<int> _selectedDocIds = {};

  bool _sendWhatsapp = true;
  bool _sendEmail = true;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    final hasPhone = (widget.lead.phone ?? '').trim().isNotEmpty;
    final hasEmail = (widget.lead.email ?? '').trim().isNotEmpty;
    _sendWhatsapp = hasPhone;
    _sendEmail = hasEmail;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool _isDocUploaded(Map<String, dynamic> doc) {
    if (doc['isUploaded'] == true || doc['uploadStatus'] == 'UPLOADED') return true;
    final url = (doc['fileUrl'] as String?)?.trim() ?? '';
    if (url.isEmpty) return false;
    return !url.contains('storage.qbapp.online/documents/');
  }

  String? _extractApiErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final missing = data['missingDocuments'];
        if (missing is List && missing.isNotEmpty) {
          final names = missing
              .map((m) => (m is Map ? m['title'] : m)?.toString())
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .join(', ');
          final base = data['message']?.toString() ??
              'Some selected company documents have not been uploaded.';
          return names.isEmpty ? '$base $_missingDocsHint' : '$base Missing: $names. $_missingDocsHint';
        }
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    }
    return null;
  }

  Future<void> _loadDocuments() async {
    try {
      final response = await ref.read(apiClientProvider).get('/mobile/send-details/documents');
      final raw = response.data;
      final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] as List : []);

      if (mounted) {
        final parsed = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        setState(() {
          _documents = parsed;
          for (final doc in parsed) {
            final id = (doc['id'] as num?)?.toInt();
            if (id != null && (doc['isActive'] ?? true) && _isDocUploaded(doc)) {
              _selectedDocIds.add(id);
            }
          }
          _loadingDocs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Future<void> _dispatch() async {
    final channels = <String>[];
    if (_sendWhatsapp) channels.add('WHATSAPP');
    if (_sendEmail) channels.add('EMAIL');

    if (channels.isEmpty) {
      AppToast.error(context, 'Please select at platform channel (WhatsApp or Email)');
      return;
    }

    if (_selectedDocIds.isEmpty) {
      AppToast.error(context, 'Please select at least one document to send');
      return;
    }

    final missingSelected = _documents.where((doc) {
      final id = (doc['id'] as num?)?.toInt();
      return id != null && _selectedDocIds.contains(id) && !_isDocUploaded(doc);
    }).map((doc) => doc['title']?.toString() ?? 'Document').toList();

    if (missingSelected.isNotEmpty) {
      AppToast.error(
        context,
        'Some selected company documents have not been uploaded. Missing: ${missingSelected.join(', ')}. $_missingDocsHint',
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final payload = {
        'channels': channels,
        'documentIds': _selectedDocIds.toList(),
        if (_noteController.text.trim().isNotEmpty) 'customNote': _noteController.text.trim(),
      };

      final response = await ref.read(apiClientProvider).post(
        '/mobile/leads/${widget.lead.id}/send-details',
        data: payload,
      );
      final raw = response.data;
      final data = raw is Map && raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
      final overall = data['overallStatus']?.toString().toUpperCase() ?? '';
      final waStatus = data['whatsappStatus']?.toString().toUpperCase() ?? '';
      final emStatus = data['emailStatus']?.toString().toUpperCase() ?? '';
      String? waErr;
      String? emErr;
      if (waStatus != 'SENT') {
        final nested = data['whatsappResult'];
        waErr = (nested is Map ? nested['error'] : null)?.toString().trim();
        waErr = waErr?.isNotEmpty == true ? waErr : data['whatsappError']?.toString().trim();
        if (waErr != null && waErr.isEmpty) waErr = null;
      }
      if (emStatus != 'SENT') {
        final nested = data['emailResult'];
        emErr = (nested is Map ? nested['error'] : null)?.toString().trim();
        emErr = emErr?.isNotEmpty == true ? emErr : data['emailError']?.toString().trim();
        if (emErr != null && emErr.isEmpty) emErr = null;
      }
      final channelNotes = <String>[
        if (waErr != null) 'WhatsApp: $waErr',
        if (emErr != null) 'Email: $emErr',
      ];

      if (mounted) {
        if (overall == 'FAILED') {
          AppToast.error(context, channelNotes.isEmpty ? 'The details package was not delivered.' : channelNotes.join(' '));
        } else if (overall == 'PARTIALLY_COMPLETED' || overall == 'PARTIAL') {
          AppToast.info(context, channelNotes.isEmpty ? 'The details package was only partly delivered.' : channelNotes.join(' '));
        } else {
          AppToast.success(context, 'Business details package sent successfully!');
        }
        widget.onDispatched?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final parsed = _extractApiErrorMessage(e);
        AppToast.error(context, parsed ?? 'Failed to dispatch Send Details: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _previewDoc(Map<String, dynamic> doc) async {
    final url = (doc['previewUrl'] as String?)?.trim();
    if (!_isDocUploaded(doc) || url == null || url.isEmpty) {
      AppToast.info(context, 'Upload this PDF in Send Details Settings before previewing.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppToast.error(context, 'Could not open document link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final fullName = [lead.firstName, lead.lastName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty ? fullName : (lead.companyName.isNotEmpty ? lead.companyName : 'Lead #${lead.id}');
    final hasPhone = (lead.phone ?? '').trim().isNotEmpty;
    final hasEmail = (lead.email ?? '').trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Remix.send_plane_2_fill, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Details Package',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Remix.close_line, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lead Contact Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Remix.phone_line, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasPhone ? (lead.phone ?? '') : 'No phone number available',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasPhone ? const Color(0xFF1E293B) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lead.stage?.name ?? lead.status,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Remix.mail_line, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasEmail ? lead.email! : 'No email address available',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasEmail ? const Color(0xFF1E293B) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Channels
                  Text(
                    'CHANNELS TO SEND THROUGH',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: hasPhone ? () => setState(() => _sendWhatsapp = !_sendWhatsapp) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _sendWhatsapp ? const Color(0xFFE8F7ED) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _sendWhatsapp ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _sendWhatsapp ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                                  color: _sendWhatsapp ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'WhatsApp',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: hasPhone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: hasEmail ? () => setState(() => _sendEmail = !_sendEmail) : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _sendEmail ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _sendEmail ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _sendEmail ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                                  color: _sendEmail ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Email',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: hasEmail ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Documents Checklist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DOCUMENTS TO INCLUDE (${_selectedDocIds.length}/${_documents.length})',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xFF64748B)),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final uploadedIds = _documents
                                .where(_isDocUploaded)
                                .map((doc) => (doc['id'] as num?)?.toInt())
                                .whereType<int>()
                                .toList();
                            if (_selectedDocIds.length == uploadedIds.length && uploadedIds.isNotEmpty) {
                              _selectedDocIds.clear();
                            } else {
                              _selectedDocIds
                                ..clear()
                                ..addAll(uploadedIds);
                            }
                          });
                        },
                        child: Text(
                          _selectedDocIds.isNotEmpty &&
                                  _selectedDocIds.length ==
                                      _documents.where(_isDocUploaded).length
                              ? 'Deselect All'
                              : 'Select All',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_loadingDocs)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_documents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No documents configured yet in Admin Panel',
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    )
                  else
                    ..._documents.map((doc) {
                      final id = (doc['id'] as num?)?.toInt() ?? 0;
                      final isSelected = _selectedDocIds.contains(id);
                      final title = doc['title'] ?? 'Document';
                      final fileName = doc['fileName'] ?? 'document.pdf';
                      final uploaded = _isDocUploaded(doc);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFAFAFC) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedDocIds.add(id);
                                  } else {
                                    _selectedDocIds.remove(id);
                                  }
                                });
                              },
                            ),
                            const Icon(Remix.file_pdf_fill, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    uploaded ? fileName : 'PDF not uploaded',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: uploaded ? const Color(0xFF64748B) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!uploaded)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  'MISSING',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Remix.eye_line,
                                size: 18,
                                color: uploaded ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                              ),
                              onPressed: uploaded ? () => _previewDoc(doc) : null,
                              tooltip: 'Preview',
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // Optional note
                  Text(
                    'OPTIONAL NOTE TO LEAD',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. As discussed over call, sharing our revised package...',
                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Send Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSending ? null : _dispatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Remix.send_plane_fill, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Send Details Now',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
