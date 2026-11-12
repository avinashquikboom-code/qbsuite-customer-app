import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

import 'package:quickboom_crm_customer/core/services/employee_location_service.dart';
import 'visitor_completed_success_view.dart';

class VisitorReviewView extends ConsumerStatefulWidget {
  final Map<String, dynamic> visit;
  final String status;
  final String? followUpDate;
  final String remarks;
  final Map<String, dynamic>? requirementSummary;
  final VoidCallback? onVisitUpdated;

  const VisitorReviewView({
    super.key,
    required this.visit,
    required this.status,
    this.followUpDate,
    required this.remarks,
    this.requirementSummary,
    this.onVisitUpdated,
  });

  @override
  ConsumerState<VisitorReviewView> createState() => _VisitorReviewViewState();
}

class _VisitorReviewViewState extends ConsumerState<VisitorReviewView> {
  int _rating = 5;
  final TextEditingController _feedbackController = TextEditingController();
  final List<Offset?> _signaturePoints = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitReview() async {
    final visitId = widget.visit['id'];
    if (visitId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final feedback = _feedbackController.text.trim();
      final outcomeText = '${widget.status}: ${widget.remarks}'.trim();

      final locResult = await EmployeeLocationService.getCurrentLocation(
        timeout: const Duration(seconds: 8),
      );
      final Map<String, dynamic> completeData = {
        'outcome': outcomeText,
        'rating': _rating,
        'feedback': feedback,
      };
      if (widget.followUpDate != null && widget.followUpDate!.isNotEmpty) {
        completeData['nextFollowUpDate'] = widget.followUpDate;
      }
      if (locResult.isSuccess && locResult.position != null) {
        completeData['latitude'] = locResult.position!.latitude;
        completeData['longitude'] = locResult.position!.longitude;
      }

      final res = await ref
          .read(apiClientProvider)
          .patch('/mobile/visits/$visitId/complete', data: completeData);

      // Invalidate leads so Visit Done lead disappears from Visitor Lead pipeline
      

      Map<String, dynamic> updatedVisit = widget.visit;
      if (res.data != null && res.data is Map) {
        final raw = res.data['data'] is Map
            ? res.data['data']
            : (res.data['visit'] is Map ? res.data['visit'] : res.data);
        updatedVisit = Map<String, dynamic>.from(raw);
      }

      widget.onVisitUpdated?.call();

      if (mounted) {
        final customerName =
            updatedVisit['customer']?.toString() ??
            updatedVisit['customerName']?.toString() ??
            widget.visit['customer']?.toString() ??
            'Client';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VisitorCompletedSuccessView(
              visit: updatedVisit,
              customerName: customerName,
              rating: _rating,
              outcome: widget.status,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to complete visit: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Customer Review',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Avatar & Rate Your Experience Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Remix.user_3_fill,
                        color: Color(0xFF2563EB),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Rate Your Experience',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return InkWell(
                        onTap: () => setState(() => _rating = star),
                        borderRadius: BorderRadius.circular(100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            star <= _rating ? Remix.star_fill : Remix.star_line,
                            color: star <= _rating
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFE2E8F0),
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Customer Feedback Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Feedback',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Very professional approach. Solutions are well explained. Will definitely work together.',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textPlaceholder,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Customer Signature Section (Optional)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customer Signature (Optional)',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _signaturePoints.clear();
                          });
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _signaturePoints.add(details.localPosition);
                          });
                        },
                        onPanEnd: (details) {
                          _signaturePoints.add(null);
                        },
                        child: CustomPaint(
                          painter: _SignaturePainter(_signaturePoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSubmitting ? null : _handleSubmitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
