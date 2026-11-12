import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/influencer_model.dart';
import '../services/customer_influencer_service.dart';
import 'customer_influencers_list_view.dart';

/// Screen — Influencer Application Status View
class InfluencerApplicationStatusView extends ConsumerStatefulWidget {
  final String? email;
  final InfluencerModel? initialInfluencer;

  const InfluencerApplicationStatusView({
    super.key,
    this.email,
    this.initialInfluencer,
  });

  @override
  ConsumerState<InfluencerApplicationStatusView> createState() =>
      _InfluencerApplicationStatusViewState();
}

class _InfluencerApplicationStatusViewState
    extends ConsumerState<InfluencerApplicationStatusView> {
  late final TextEditingController _emailController;
  InfluencerModel? _influencer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _influencer = widget.initialInfluencer;
    if (_influencer == null &&
        widget.email != null &&
        widget.email!.isNotEmpty) {
      _fetchStatus();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _errorMessage = 'Please enter your registered email address',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final res = await service.checkApplicationStatus(email: email);
      if (mounted) {
        setState(() {
          _influencer = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _showResubmitSheet(BuildContext context, InfluencerModel inf) {
    final bioCtrl = TextEditingController(text: inf.bio ?? '');
    final instaCtrl = TextEditingController(text: inf.handle ?? '');
    final followersCtrl = TextEditingController(
      text: inf.followers > 0 ? inf.followers.toString() : '',
    );
    final messenger = ScaffoldMessenger.of(context);
    bool isResubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Update & Resubmit Profile',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Remix.close_line),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Correct any issues noted by the admin team and resubmit for review.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: instaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Instagram Profile / Handle',
                      labelStyle: GoogleFonts.outfit(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: followersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Followers Count',
                      labelStyle: GoogleFonts.outfit(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Updated Bio & Details',
                      labelStyle: GoogleFonts.outfit(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isResubmitting
                          ? null
                          : () async {
                              setSheetState(() => isResubmitting = true);
                              try {
                                final service = ref.read(
                                  customerInfluencerServiceProvider,
                                );
                                final updated = await service
                                    .resubmitApplication(inf.id, {
                                      'instagramHandle': instaCtrl.text.trim(),
                                      'bio': bioCtrl.text.trim(),
                                      'followers':
                                          int.tryParse(
                                            followersCtrl.text.trim(),
                                          ) ??
                                          inf.followers,
                                    });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                if (updated != null) {
                                  setState(() => _influencer = updated);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Application resubmitted with status PENDING!',
                                      ),
                                      backgroundColor: AppColors.primaryDark,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isResubmitting = false);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Resubmission failed: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      child: isResubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit For Re-review',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Application Status',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Lookup Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Creator Application',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your registered email address to check your application review status.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.outfit(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. rohan.creator@gmail.com',
                            prefixIcon: const Icon(Remix.mail_line, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _fetchStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Remix.search_line,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Remix.error_warning_line,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Live Status Card
            if (_influencer != null) _buildStatusCard(context, _influencer!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, InfluencerModel inf) {
    final status = inf.status.toUpperCase();

    Color bg;
    Color border;
    Color primaryColor;
    IconData icon;
    String title;
    String description;

    switch (status) {
      case 'APPROVED':
      case 'ACTIVE':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        primaryColor = const Color(0xFF059669);
        icon = Remix.checkbox_circle_line;
        title = 'Application Approved & Live!';
        description =
            'Congratulations! Your creator profile has been verified and approved by admin. You are now live in the customer Influencer Hub.';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        primaryColor = const Color(0xFFDC2626);
        icon = Remix.close_circle_line;
        title = 'Application Rejected';
        description =
            'Your application could not be approved at this time. Please see the rejection reason below and update your profile to resubmit.';
        break;
      case 'SUSPENDED':
        bg = const Color(0xFFF9FAFB);
        border = const Color(0xFFE5E7EB);
        primaryColor = const Color(0xFF4B5563);
        icon = Remix.forbid_line;
        title = 'Account Suspended';
        description =
            'Your influencer account has been suspended by the platform administration. Please contact support.';
        break;
      case 'PENDING':
      default:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        primaryColor = const Color(0xFFD97706);
        icon = Remix.time_line;
        title = 'Application Under Review';
        description =
            'Your creator application has been submitted and is currently being reviewed by our admin team. Check back soon.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status: $status',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),

          // Rejection Reason Box
          if (status == 'REJECTED' && inf.rejectionReason != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Remix.error_warning_line,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reason from Admin:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inf.rejectionReason!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Creator Profile Details
          Text(
            'Submitted Profile Summary',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          _buildDetailRow('Full Name', inf.name),
          _buildDetailRow('Email', inf.email ?? '—'),
          _buildDetailRow('Mobile', inf.phone ?? '—'),
          _buildDetailRow('Category', inf.categoryName),
          _buildDetailRow('Followers', inf.followersCount),

          const SizedBox(height: 20),

          // Action Buttons based on status
          if (status == 'REJECTED')
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showResubmitSheet(context, inf),
                icon: const Icon(
                  Remix.edit_line,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Edit & Resubmit Application',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (status == 'APPROVED' || status == 'ACTIVE')
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerInfluencersListView(),
                    ),
                  );
                },
                icon: const Icon(
                  Remix.external_link_line,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Browse Influencer Hub',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (status == 'PENDING')
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD97706)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _fetchStatus,
                icon: const Icon(
                  Remix.refresh_line,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                label: Text(
                  'Refresh Status',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
