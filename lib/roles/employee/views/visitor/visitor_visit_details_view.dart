import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/employee_location_service.dart';
import 'package:quickboom_crm_customer/core/services/employee_live_tracking_service.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/shared/widgets/status_badge.dart';
import 'package:quickboom_crm_customer/roles/employee/views/visitor/visitor_requirement_view.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

class VisitorVisitDetailsView extends ConsumerStatefulWidget {
  final Map<String, dynamic> visit;
  final VoidCallback? onVisitUpdated;

  const VisitorVisitDetailsView({
    super.key,
    required this.visit,
    this.onVisitUpdated,
  });

  @override
  ConsumerState<VisitorVisitDetailsView> createState() =>
      _VisitorVisitDetailsViewState();
}

class _VisitorVisitDetailsViewState
    extends ConsumerState<VisitorVisitDetailsView> {
  late Map<String, dynamic> _visit;
  bool _isLoading = false;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _visit = Map<String, dynamic>.from(widget.visit);
    _refreshVisitDetails();
  }

  Future<void> _refreshVisitDetails() async {
    final visitId = _visit['id'];
    if (visitId == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/mobile/visits/$visitId');
      if (res.data != null && res.data is Map) {
        final raw = res.data['data'] is Map
            ? res.data['data']
            : (res.data['visit'] is Map ? res.data['visit'] : res.data);
        if (mounted) {
          setState(() {
            _visit = Map<String, dynamic>.from(raw);
          });
        }
      }
    } catch (e) {
      debugPrint('[VisitorVisitDetailsView] Refresh error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) AppToast.error(context, 'Could not open phone dialer');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppToast.error(context, 'Could not open WhatsApp');
    }
  }

  Future<void> _openMap() async {
    final rawLat = _visit['latitude'] ?? _visit['lat'];
    final rawLng = _visit['longitude'] ?? _visit['lng'] ?? _visit['lon'];
    final rawLoc = _visit['location']?.toString().trim() ?? '';

    String? destQuery;
    if (rawLat != null && rawLng != null) {
      final lat = double.tryParse(rawLat.toString());
      final lng = double.tryParse(rawLng.toString());
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        destQuery = '$lat,$lng';
      }
    }

    if (destQuery == null &&
        rawLoc.isNotEmpty &&
        rawLoc.toUpperCase() != 'CLIENT OFFICE' &&
        rawLoc.toUpperCase() != 'N/A') {
      destQuery = Uri.encodeComponent(rawLoc);
    }

    if (destQuery == null || destQuery.isEmpty) {
      if (mounted) {
        AppToast.error(context, 'Location is not available.');
      }
      return;
    }

    // Capture visitor current location to plot track from current location to destination
    double? curLat;
    double? curLng;
    try {
      final locResult = await EmployeeLocationService.getCurrentLocation(
        timeout: const Duration(seconds: 3),
      );
      if (locResult.isSuccess && locResult.position != null) {
        curLat = locResult.position!.latitude;
        curLng = locResult.position!.longitude;
      }
    } catch (_) {}

    final hasCurLoc =
        curLat != null && curLng != null && (curLat != 0 || curLng != 0);

    // Google Maps directions URL showing track/route from visitor current location to visit destination
    final originParam = hasCurLoc ? '&origin=$curLat,$curLng' : '';
    final googleMapsDirectionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destQuery$originParam',
    );

    Uri nativeUri;
    final Uri fallbackUri = googleMapsDirectionsUri;

    if (Platform.isIOS) {
      final saddr = hasCurLoc ? '&saddr=$curLat,$curLng' : '';
      nativeUri = Uri.parse(
        'https://maps.apple.com/?daddr=$destQuery$saddr&dirflg=d',
      );
    } else {
      nativeUri = googleMapsDirectionsUri;
    }

    try {
      bool launched = false;
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched) {
        if (await canLaunchUrl(fallbackUri)) {
          launched = await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          launched = await launchUrl(
            fallbackUri,
            mode: LaunchMode.platformDefault,
          );
        }
      }
      if (!launched && mounted) {
        AppToast.error(context, 'Could not open map application.');
      }
    } catch (_) {
      try {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          AppToast.error(context, 'Could not open map application.');
        }
      }
    }
  }

  Future<void> _startVisit() async {
    final visitId = _visit['id'];
    if (visitId == null) return;

    setState(() => _isActionLoading = true);
    try {
      // 1. Capture Visitor's current GPS location
      final locResult = await EmployeeLocationService.getCurrentLocation(
        timeout: const Duration(seconds: 10),
      );

      final Map<String, dynamic> checkInData = {};
      if (locResult.isSuccess && locResult.position != null) {
        checkInData['latitude'] = locResult.position!.latitude;
        checkInData['longitude'] = locResult.position!.longitude;
      }

      // 2. Perform check-in on backend
      final res = await ref
          .read(apiClientProvider)
          .patch('/mobile/visits/$visitId/check-in', data: checkInData);

      // 3. Start live tracking for the ongoing visit
      try {
        EmployeeLiveTrackingService().startTracking(
          apiClient: ref.read(apiClientProvider),
        );
      } catch (_) {}

      if (mounted) {
        AppToast.success(context, 'Visit started! GPS check-in recorded.');
        if (res.data != null && res.data is Map) {
          final raw = res.data['data'] is Map
              ? res.data['data']
              : (res.data['visit'] is Map ? res.data['visit'] : res.data);
          setState(() {
            _visit = Map<String, dynamic>.from(raw);
          });
        }
        widget.onVisitUpdated?.call();

        // Navigate directly to Requirement Form
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitorRequirementView(
              visit: _visit,
              onVisitUpdated: () {
                _refreshVisitDetails();
                widget.onVisitUpdated?.call();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to start visit: $e');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  List<Widget> _visitPhotoSection() {
    final raw = _visit['photos'];
    final photos = raw is List ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).where((item) => (item['url']?.toString().trim().isNotEmpty ?? false)).toList() : <Map<String, dynamic>>[];
    return [
      const SizedBox(height: 16),
      Text('Visit photos', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      if (photos.isEmpty)
        Text('No photos are attached to this visit.', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary))
      else
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final photo = photos[index];
              final url = photo['url'].toString();
              final who = photo['uploadedBy']?.toString() ?? '';
              return GestureDetector(
                onTap: () => showDialog<void>(context: context, builder: (context) => Dialog(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 92, height: 72, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 92, height: 72, child: Icon(Remix.image_line)))),
                  Text(who.isEmpty ? 'Photo' : who, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary)),
                ]),
              );
            },
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = (_visit['status']?.toString() ?? 'SCHEDULED')
        .toUpperCase();
    final isCompleted = statusStr == 'COMPLETED' || statusStr == 'DONE';
    final isOngoing = statusStr == 'IN_PROGRESS' || statusStr == 'ONGOING';
    final isScheduled = !isCompleted && !isOngoing;

    final customerName =
        _visit['customer']?.toString() ??
        _visit['customerName']?.toString() ??
        'Client Meeting';
    final purpose = _visit['purpose']?.toString() ?? 'Field Visit Consultation';
    final rawLoc = _visit['location']?.toString().trim() ?? '';
    final leadMap = _visit['lead'];
    String locDisplay = rawLoc;
    if (locDisplay.isEmpty || locDisplay.toUpperCase() == 'N/A') {
      if (leadMap is Map) {
        final leadAddr = leadMap['address']?.toString().trim() ?? '';
        final leadCity = leadMap['city']?.toString().trim() ?? '';
        final combined = [
          leadAddr,
          leadCity,
        ].where((s) => s.isNotEmpty).join(', ');
        if (combined.isNotEmpty) {
          locDisplay = combined;
        }
      }
    }
    final location = locDisplay.isNotEmpty ? locDisplay : 'Client Office';
    final dateStr = _visit['date']?.toString() ?? '';
    final timeStr = _visit['time']?.toString() ?? '';
    final phone = _visit['phone']?.toString();
    final assignedVisitor =
        _visit['assignedEmployee']?.toString() ??
        (_visit['employee'] is Map
            ? '${_visit['employee']['firstName'] ?? ''} ${_visit['employee']['lastName'] ?? ''}'
                  .trim()
            : null);
    final completedBy = _visit['completedBy']?.toString();
    final notes = _visit['notes']?.toString();
    final outcome = _visit['outcome']?.toString();

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
          'Visit Details',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Remix.refresh_line,
              color: AppColors.textSecondary,
            ),
            onPressed: _refreshVisitDetails,
          ),
        ],
      ),
      body: _isLoading
          ? _buildVisitDetailsSkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Remix.building_2_fill,
                                color: AppColors.primaryDark,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    purpose,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: isCompleted
                                  ? 'Completed'
                                  : (isOngoing ? 'Ongoing' : 'Scheduled'),
                              type: isCompleted
                                  ? BadgeType.completed
                                  : (isOngoing
                                        ? BadgeType.inProgress
                                        : BadgeType.scheduled),
                            ),
                          ],
                        ),

                        if (phone != null && phone.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(
                            height: 1,
                            color: AppColors.borderLight,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  phone,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              // Call Button
                              InkWell(
                                onTap: () => _makePhoneCall(phone),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Remix.phone_fill,
                                        size: 14,
                                        color: AppColors.primaryDark,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Call',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // WhatsApp Button
                              InkWell(
                                onTap: () => _openWhatsApp(phone),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Remix.whatsapp_fill,
                                        size: 14,
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Chat',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Schedule & Location Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule & Location',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.pillBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Remix.time_line,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit Time',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$timeStr, $dateStr',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openMap(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Remix.map_pin_2_fill,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          location,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Remix.navigation_line,
                                      color: Color(0xFF2563EB),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Assignment & Notes Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visit Information',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (assignedVisitor != null &&
                            assignedVisitor.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Remix.user_star_line,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Assigned Visitor: ',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                assignedVisitor,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (completedBy != null && completedBy.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Remix.checkbox_circle_line,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Visited By: ',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                completedBy,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        ..._visitPhotoSection(),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Preparation & Notes:',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              notes,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        if (outcome != null && outcome.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Recorded Outcome:',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.subtleGreenBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              outcome,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
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
                child: isScheduled
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
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
                                onPressed: _isActionLoading
                                    ? null
                                    : _startVisit,
                                icon: _isActionLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Remix.play_fill, size: 20),
                                label: Text(
                                  _isActionLoading
                                      ? 'STARTING...'
                                      : 'START VISIT',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VisitorRequirementView(
                                        visit: _visit,
                                        onVisitUpdated: () {
                                          _refreshVisitDetails();
                                          widget.onVisitUpdated?.call();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Remix.file_list_3_line,
                                  size: 18,
                                ),
                                label: Text(
                                  'REQUIREMENTS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : (isOngoing
                          ? SizedBox(
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
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VisitorRequirementView(
                                        visit: _visit,
                                        onVisitUpdated: () {
                                          _refreshVisitDetails();
                                          widget.onVisitUpdated?.call();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Remix.file_list_3_line,
                                  size: 20,
                                ),
                                label: Text(
                                  'CONTINUE TO REQUIREMENTS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Remix.checkbox_circle_fill,
                                    color: AppColors.primaryDark,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'VISIT COMPLETED & RECORDED',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            )),
              ),
            ),
    );
  }

  Widget _buildVisitDetailsSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonProfileCard(),
          SizedBox(height: 16),
          SkeletonCard(),
          SizedBox(height: 16),
          SkeletonCard(),
        ],
      ),
    );
  }
}
