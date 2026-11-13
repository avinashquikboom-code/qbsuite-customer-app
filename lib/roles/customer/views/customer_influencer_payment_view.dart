import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/services/razorpay_checkout_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/influencer_model.dart';
import '../services/customer_influencer_service.dart';
import '../services/customer_subscription_service.dart';
import '../viewmodels/customer_influencer_viewmodel.dart';
import 'customer_influencer_booking_confirmed_view.dart';

/// Screen 5 — Customer Influencer Payment
/// Only 2 payment methods: Online (Razorpay) and Offline (Bank Transfer)
class CustomerInfluencerPaymentView extends ConsumerStatefulWidget {
  final InfluencerModel creator;
  final InfluencerPackageModel package;
  final String campaignDate;
  final String brandName;
  final String contactPerson;
  final String mobileNumber;
  final String email;
  final String businessName;
  final String? instagramId;
  final String campaignObjective;
  final String? notes;

  const CustomerInfluencerPaymentView({
    super.key,
    required this.creator,
    required this.package,
    required this.campaignDate,
    required this.brandName,
    required this.contactPerson,
    required this.mobileNumber,
    required this.email,
    required this.businessName,
    this.instagramId,
    required this.campaignObjective,
    this.notes,
  });

  @override
  ConsumerState<CustomerInfluencerPaymentView> createState() =>
      _CustomerInfluencerPaymentViewState();
}

class _CustomerInfluencerPaymentViewState
    extends ConsumerState<CustomerInfluencerPaymentView> {
  // 0 = Online Payment (Razorpay), 1 = Offline Payment
  int _selectedMethodIndex = 0;
  bool _isProcessing = false;

  final TextEditingController _utrController = TextEditingController();
  final TextEditingController _offlineNotesController = TextEditingController();
  Map<String, dynamic>? _paymentConfig;

  late double _packageCost;
  late double _platformFee;
  late double _gst;
  late double _totalAmount;

  @override
  void initState() {
    super.initState();
    _packageCost = widget.package.price;
    _platformFee = _packageCost > 0 ? 500.0 : 0.0;
    _gst = (_packageCost * 0.18).roundToDouble();
    _totalAmount = _packageCost + _platformFee + _gst;

    _loadPaymentConfig();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final config = await ref
          .read(customerSubscriptionServiceProvider)
          .getPaymentConfig();
      if (mounted) {
        setState(() {
          _paymentConfig = config;
        });
      }
    } catch (e) {
      debugPrint('[PAYMENT_CONFIG_ERROR] $e');
    }
  }

  @override
  void dispose() {
    _utrController.dispose();
    _offlineNotesController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedMethodIndex == 0) {
      await _processRazorpayPayment();
    } else {
      await _processOfflinePayment();
    }
  }

  Future<void> _processRazorpayPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final int? pkgId = int.tryParse(widget.package.id);

      // 1. Authoritative Server-Side Booking Creation (Calculates fee, GST & Booking ID & Razorpay Order)
      final createdBooking = await service.createBooking(
        influencerId: widget.creator.id,
        packageId: pkgId,
        campaignDate: widget.campaignDate,
        brandName: widget.brandName,
        contactPerson: widget.contactPerson,
        mobileNumber: widget.mobileNumber,
        email: widget.email,
        businessName: widget.businessName,
        instagramId: widget.instagramId,
        campaignObjective: widget.campaignObjective,
        notes: widget.notes,
      );

      if (createdBooking == null) {
        throw Exception(
          'Server failed to create influencer booking. Please try again.',
        );
      }

      final booking = createdBooking;
      final rzpOrderId = booking.razorpayOrderId;
      final rzpKeyId =
          booking.razorpayKeyId ??
          _paymentConfig?['razorpayKeyId']?.toString() ??
          '';

      if (rzpOrderId == null || rzpOrderId.isEmpty || rzpKeyId.isEmpty) {
        throw Exception(
          'Online payment gateway is temporarily unavailable. Please use Offline Payment or try again later.',
        );
      }

      // 2. Open Native Razorpay Checkout Modal
      final rzpService = ref.read(razorpayCheckoutServiceProvider);
      final checkoutResult = await rzpService.openCheckout(
        keyId: rzpKeyId,
        orderId: rzpOrderId,
        amountInPaise: (booking.totalAmount * 100).round(),
        planName: '${widget.package.name} Package',
        businessName: widget.businessName.isNotEmpty
            ? widget.businessName
            : 'QuickBoom',
        customerEmail: widget.email,
        customerPhone: widget.mobileNumber,
      );

      if (!checkoutResult.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                checkoutResult.errorMessage ?? 'Payment cancelled or failed.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }

      // 3. Authoritative HMAC Signature Verification on Server
      final verified = await service.verifyPayment(
        bookingId: booking.bookingId,
        razorpayPaymentId: checkoutResult.paymentId!,
        razorpayOrderId: checkoutResult.orderId ?? rzpOrderId,
        razorpaySignature: checkoutResult.signature!,
        paymentMethod: 'RAZORPAY',
      );

      if (!verified) {
        throw Exception('Payment signature verification failed on server.');
      }

      // 4. Update Customer Bookings State & Refresh
      final confirmedBooking = booking.copyWith(
        paymentStatus: 'PAID',
        status: 'CONFIRMED',
        paymentMethod: 'RAZORPAY',
        razorpayPaymentId: checkoutResult.paymentId,
      );
      ref
          .read(customerInfluencerBookingsProvider.notifier)
          .addBooking(confirmedBooking);
      ref.read(customerInfluencerBookingsProvider.notifier).refresh();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerInfluencerBookingConfirmedView(
              booking: confirmedBooking,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RAZORPAY_PAYMENT_ERROR] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processOfflinePayment() async {
    final utr = _utrController.text.trim();
    if (utr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the transaction reference / UTR number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final service = ref.read(customerInfluencerServiceProvider);
      final int? pkgId = int.tryParse(widget.package.id);

      // 1. Authoritative Server-Side Booking Creation
      final createdBooking = await service.createBooking(
        influencerId: widget.creator.id,
        packageId: pkgId,
        campaignDate: widget.campaignDate,
        brandName: widget.brandName,
        contactPerson: widget.contactPerson,
        mobileNumber: widget.mobileNumber,
        email: widget.email,
        businessName: widget.businessName,
        instagramId: widget.instagramId,
        campaignObjective: widget.campaignObjective,
        notes: widget.notes,
      );

      if (createdBooking == null) {
        throw Exception(
          'Server failed to create influencer booking. Please try again.',
        );
      }

      final booking = createdBooking;

      // 2. Submit Offline Payment Reference (PENDING_VERIFICATION)
      final verified = await service.verifyPayment(
        bookingId: booking.bookingId,
        razorpayPaymentId: 'offline_$utr',
        razorpayOrderId:
            booking.razorpayOrderId ?? 'OFFLINE_${booking.bookingId}',
        razorpaySignature: 'OFFLINE',
        paymentMethod: 'OFFLINE',
        referenceNumber: utr,
        notes: _offlineNotesController.text.trim(),
      );

      if (!verified) {
        throw Exception(
          'Failed to record offline payment reference on server.',
        );
      }

      final pendingBooking = booking.copyWith(
        paymentStatus: 'PENDING_VERIFICATION',
        status: 'PENDING',
        paymentMethod: 'OFFLINE',
        razorpayPaymentId: utr,
      );

      ref
          .read(customerInfluencerBookingsProvider.notifier)
          .addBooking(pendingBooking);
      ref.read(customerInfluencerBookingsProvider.notifier).refresh();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CustomerInfluencerBookingConfirmedView(booking: pendingBooking),
          ),
        );
      }
    } catch (e) {
      debugPrint('[OFFLINE_PAYMENT_ERROR] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline payment submission error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
          'Payment',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title: Order Summary
                  Text(
                    'Order Summary',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Order Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Creator Row
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: widget.creator.effectiveImageUrl.isNotEmpty
                                  ? Image.network(
                                      widget.creator.effectiveImageUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) =>
                                          const Icon(Remix.user_3_line),
                                    )
                                  : const Icon(Remix.user_3_line),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.creator.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${widget.package.name} Package',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),

                        // Line items
                        _buildSummaryRow('Campaign Date', widget.campaignDate),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                          'Package Cost',
                          '₹${_packageCost.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                          'Platform Fee',
                          '₹${_platformFee.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                          'GST (18%)',
                          '₹${_gst.toStringAsFixed(0)}',
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),

                        // Total Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Section Title: Select Payment Method
                  Text(
                    'Select Payment Method',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option 0: ONLINE PAYMENT - Razorpay
                  _buildPaymentOptionCard(
                    index: 0,
                    category: 'ONLINE PAYMENT',
                    title: 'Razorpay',
                    subtitle: 'Pay securely using Razorpay',
                    icon: Remix.shield_check_line,
                    badge: 'RAZORPAY',
                  ),

                  // Option 1: OFFLINE PAYMENT - Bank Transfer
                  _buildPaymentOptionCard(
                    index: 1,
                    category: 'OFFLINE PAYMENT',
                    title: 'Bank Transfer / Offline Payment',
                    subtitle: 'Submit payment reference for verification',
                    icon: Remix.bank_line,
                  ),

                  // If Offline Payment is selected, show Bank Details Card & UTR Input
                  if (_selectedMethodIndex == 1) _buildOfflinePaymentSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _selectedMethodIndex == 0
                            ? 'Pay ₹${_totalAmount.toStringAsFixed(0)} with Razorpay'
                            : 'Submit Offline Payment',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
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
    );
  }

  Widget _buildPaymentOptionCard({
    required int index,
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _selectedMethodIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethodIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Radio Circle
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: isSelected
                              ? AppColors.primaryDark
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryDark
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflinePaymentSection() {
    final bankDetails =
        (_paymentConfig != null && _paymentConfig!['bankDetails'] is Map)
        ? Map<String, dynamic>.from(_paymentConfig!['bankDetails'] as Map)
        : <String, dynamic>{};

    final bankName = bankDetails['bankName']?.toString() ?? 'HDFC Bank';
    final accountNo =
        bankDetails['accountNumber']?.toString() ?? '50200088991122';
    final ifsc = bankDetails['ifscCode']?.toString() ?? 'HDFC0000240';
    final holder =
        bankDetails['accountHolderName']?.toString() ??
        'QuickBoom Technologies Pvt Ltd';
    final upiId = bankDetails['upiId']?.toString() ?? 'quickboom@upi';

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Remix.bank_line,
                size: 15,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                'Bank Transfer Details',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBankDetailRow('Bank Name', bankName),
          _buildBankDetailRow('Account Number', accountNo, canCopy: true),
          _buildBankDetailRow('IFSC Code', ifsc, canCopy: true),
          _buildBankDetailRow('Account Name', holder),
          _buildBankDetailRow('UPI ID', upiId, canCopy: true),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Text(
            'Submit Payment Reference',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _utrController,
            enabled: !_isProcessing,
            style: GoogleFonts.outfit(fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'Transaction Reference / UTR Number *',
              labelStyle: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
              hintText: 'e.g. 12-digit UTR or Reference Number',
              hintStyle: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _offlineNotesController,
            enabled: !_isProcessing,
            style: GoogleFonts.outfit(fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'Notes / Remarks (Optional)',
              labelStyle: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
              hintText: 'e.g. Paid via Google Pay / Net Banking',
              hintStyle: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(
    String label,
    String value, {
    bool canCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Remix.file_copy_line,
                      size: 13,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
