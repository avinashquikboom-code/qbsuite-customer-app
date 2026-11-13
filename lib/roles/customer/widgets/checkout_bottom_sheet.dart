import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_subscription_service.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/current_customer_viewmodel.dart';

class CheckoutBottomSheet extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;
  final SubscriptionBillingCycle initialCycle;
  final void Function(CustomerOrder order)? onOrderSuccess;

  const CheckoutBottomSheet({
    super.key,
    required this.plan,
    required this.initialCycle,
    this.onOrderSuccess,
  });

  static Future<CustomerOrder?> show({
    required BuildContext context,
    required SubscriptionPlan plan,
    required SubscriptionBillingCycle cycle,
    void Function(CustomerOrder order)? onOrderSuccess,
  }) {
    return showModalBottomSheet<CustomerOrder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CheckoutBottomSheet(
        plan: plan,
        initialCycle: cycle,
        onOrderSuccess: onOrderSuccess,
      ),
    );
  }

  @override
  ConsumerState<CheckoutBottomSheet> createState() =>
      _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends ConsumerState<CheckoutBottomSheet> {
  late SubscriptionBillingCycle _cycle;
  bool _isProcessing = false;
  String _paymentOption = 'FULL'; // 'FULL' (100%) or 'ADVANCE' (50%)

  // Dynamic Payment Settings State
  bool _onlinePaymentEnabled = true;
  bool _offlinePaymentEnabled = true;
  String _selectedMethod = 'ONLINE'; // 'ONLINE' or 'OFFLINE' or 'NONE'
  Map<String, dynamic>? _bankDetails;
  final TextEditingController _offlineRefController = TextEditingController();
  final TextEditingController _offlineNotesController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _couponQuote;
  bool _applyingCoupon = false;

  @override
  void initState() {
    super.initState();
    _cycle = widget.initialCycle;
    _loadPaymentConfig();
  }

  @override
  void dispose() {
    _offlineRefController.dispose();
    _offlineNotesController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final service = ref.read(customerSubscriptionServiceProvider);
      final rawConfig = await service.getPaymentConfig();
      final config = PaymentMethodsConfig.fromJson(rawConfig);

      final planPm = widget.plan.paymentMethods;
      final onlineEnabled = planPm != null ? planPm.online : config.online;
      final offlineEnabled = planPm != null ? planPm.offline : config.offline;

      debugPrint('[PAYMENT] Selected Plan: ${widget.plan.name} (${widget.plan.code})');
      debugPrint('[PAYMENT] Online Payment Enabled: $onlineEnabled');
      debugPrint('[PAYMENT] Offline Payment Enabled: $offlineEnabled');
      debugPrint('[PAYMENT] Payment Methods API Response: $rawConfig');

      if (mounted) {
        setState(() {
          _onlinePaymentEnabled = onlineEnabled;
          _offlinePaymentEnabled = offlineEnabled;
          _bankDetails = config.bankDetails ?? planPm?.bankDetails;

          // Automatically select the valid method based on availability
          if (_onlinePaymentEnabled && _offlinePaymentEnabled) {
            if (_selectedMethod != 'ONLINE' && _selectedMethod != 'OFFLINE' && _selectedMethod != 'CASH') {
              _selectedMethod = 'ONLINE';
            }
          } else if (_onlinePaymentEnabled && !_offlinePaymentEnabled) {
            _selectedMethod = 'ONLINE';
          } else if (!_onlinePaymentEnabled && _offlinePaymentEnabled) {
            _selectedMethod = 'OFFLINE';
          } else {
            _selectedMethod = 'NONE';
          }
          debugPrint('[PAYMENT] Selected Payment Method: $_selectedMethod');
        });
      }
    } catch (e) {
      debugPrint('[PAYMENT] Error loading payment config: $e');
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatPrice(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;

    final lastThree = str.substring(str.length - 3);
    var remaining = str.substring(0, str.length - 3);
    final chunks = <String>[];
    while (remaining.length > 2) {
      chunks.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      chunks.insert(0, remaining);
    }
    return '${chunks.join(',')},$lastThree';
  }

  Future<void> _handlePayment() async {
    if (_isProcessing) return;
    if (!ref
        .read(permissionManagerProvider)
        .customerCan('CUSTOMER_PLANS', 'CREATE')) {
      AppToast.error(
        context,
        'You do not have permission to purchase a plan.',
        title: 'Not allowed',
      );
      return;
    }

    if (!_onlinePaymentEnabled && !_offlinePaymentEnabled) {
      AppToast.error(
        context,
        'No payment method is currently configured for this plan.',
        title: 'Payment Unavailable',
      );
      return;
    }

    final isOffline =
        (_selectedMethod == 'CASH' || _selectedMethod == 'OFFLINE') &&
        _offlinePaymentEnabled;

    if (!isOffline && !_onlinePaymentEnabled) {
      AppToast.error(
        context,
        'Online payment is currently disabled.',
        title: 'Payment Unavailable',
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (isOffline) {
        // OFFLINE PAYMENT (BANK TRANSFER / CASH / UPI) FLOW
        final refNum = _offlineRefController.text.trim();
        final notesInput = _offlineNotesController.text.trim();
        final cycleDesc = _paymentOption == 'ADVANCE' ? '50% Advance' : 'Full Payment';
        final finalNotes = notesInput.isNotEmpty
            ? '$notesInput ($cycleDesc)'
            : 'Offline payment request via Mobile App ($cycleDesc)';

        await ref
            .read(customerOrdersProvider.notifier)
            .purchasePlanOffline(
              plan: widget.plan,
              billingCycle: _cycle,
              paymentOption: _paymentOption,
              referenceNumber: refNum.isNotEmpty ? refNum : null,
              notes: finalNotes,
              couponCode: _couponQuote?['couponCode']?.toString(),
            );

        if (!mounted) return;

        // Close bottom sheet first
        Navigator.pop(context, null);

        AppToast.success(
          context,
          'Offline payment request submitted. Status: PENDING admin approval.',
          title: 'Payment Request Submitted',
        );
      } else {
        // ONLINE RAZORPAY PAYMENT FLOW
        final newOrder = await ref
            .read(customerOrdersProvider.notifier)
            .purchasePlanWithRazorpay(
              plan: widget.plan,
              billingCycle: _cycle,
              paymentOption: _paymentOption,
              couponCode: _couponQuote?['couponCode']?.toString(),
            );

        if (!mounted) return;

        // Invalidate customers list so active customer displays under Customers -> Active
        invalidateCustomersDirectory(ref);

        // Close bottom sheet first
        Navigator.pop(context, newOrder);

        AppToast.success(
          context,
          'Payment completed successfully.',
          title: 'Transaction Successful',
        );

        if (newOrder != null) {
          widget.onOrderSuccess?.call(newOrder);
        }
      }
    } catch (e) {
      if (mounted) {
        String cleanMsg = e.toString();
        if (cleanMsg.startsWith('Exception: ')) {
          cleanMsg = cleanMsg.substring(11);
        }

        // Detect if the message is actually a success message
        final lowerMsg = cleanMsg.toLowerCase();
        final isSuccess =
            lowerMsg.contains('completed successfully') ||
            lowerMsg.contains('payment completed') ||
            lowerMsg.contains('payment verified') ||
            lowerMsg.contains('subscription activated') ||
            lowerMsg.contains('request submitted') ||
            lowerMsg.contains('request created');

        if (isSuccess) {
          Navigator.pop(context, null);
          AppToast.success(
            context,
            isOffline
                ? 'Offline payment request submitted. Status: PENDING admin approval.'
                : 'Payment completed successfully.',
            title: isOffline
                ? 'Payment Request Submitted'
                : 'Transaction Successful',
          );
        } else {
          final isStaleOrUnavailable =
              lowerMsg.contains('no longer available') ||
              lowerMsg.contains('not found') ||
              lowerMsg.contains('deactivated') ||
              lowerMsg.contains('deleted') ||
              lowerMsg.contains('inactive');

          if (isStaleOrUnavailable) {
            Navigator.pop(context, null);
            ref.read(plansProvider.notifier).refresh();
            refreshAllCustomerSubscriptionData(ref);

            AppToast.error(
              context,
              'This plan is no longer available. Please refresh the plans.',
              title: 'Plan Unavailable',
            );
          } else {
            AppToast.error(
              context,
              cleanMsg.isNotEmpty
                  ? cleanMsg
                  : 'Payment could not be completed. Please try again.',
              title: 'Payment Failed',
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      AppToast.error(context, 'Enter a coupon code', title: 'Coupon');
      return;
    }
    setState(() => _applyingCoupon = true);
    try {
      final quote = await ref.read(customerSubscriptionServiceProvider).applyCoupon(
            plan: widget.plan,
            billingCycle: _cycle,
            couponCode: code,
            paymentOption: _paymentOption,
          );
      if (!mounted) return;
      setState(() => _couponQuote = quote);
      final appliedCode = quote['couponCode']?.toString() ?? code;
      AppToast.success(
        context,
        'Coupon $appliedCode applied successfully',
        title: 'Coupon applied',
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      AppToast.error(context, message, title: 'Coupon');
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedActivation = ref.watch(customerCalendarSelectedDateProvider);
    final startDate = DateTime(
      selectedActivation.year,
      selectedActivation.month,
      selectedActivation.day,
    );

    final basePrice = (_couponQuote?['originalAmount'] as num?)?.toDouble() ??
        widget.plan.priceFor(_cycle);
    final discountAmount =
        (_couponQuote?['discountAmount'] as num?)?.toDouble() ?? 0;
    final gstTax = (_couponQuote?['taxAmount'] as num?)?.toDouble() ??
        (basePrice * 0.18);
    final fullPlanTotal = (_couponQuote?['finalAmount'] as num?)?.toDouble() ??
        (basePrice + gstTax);
    final isAdvance = _paymentOption == 'ADVANCE';
    final finalAmount = (_couponQuote?['chargedTotal'] as num?)?.toDouble() ??
        (isAdvance ? (fullPlanTotal * 0.5) : fullPlanTotal);
    final remainingBalance = isAdvance ? (fullPlanTotal * 0.5) : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout Summary',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Review and confirm your subscription order',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Remix.close_line, size: 22),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Selected Plan Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.subtleGreenBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Remix.vip_crown_line,
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
                              '${widget.plan.name} Plan',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${widget.plan.userLimit} Users Included • ${_cycle.label}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Billing Cycle Selector Pill inside Checkout
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.pillBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isProcessing
                              ? null
                              : () => setState(() {
                                  _cycle = SubscriptionBillingCycle.monthly;
                                  _couponQuote = null;
                                }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _cycle == SubscriptionBillingCycle.monthly
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow:
                                  _cycle == SubscriptionBillingCycle.monthly
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Monthly (₹${_formatPrice(widget.plan.monthlyPrice)})',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight:
                                      _cycle == SubscriptionBillingCycle.monthly
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color:
                                      _cycle == SubscriptionBillingCycle.monthly
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isProcessing
                              ? null
                              : () => setState(() {
                                  _cycle = SubscriptionBillingCycle.yearly;
                                  _couponQuote = null;
                                }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _cycle == SubscriptionBillingCycle.yearly
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow:
                                  _cycle == SubscriptionBillingCycle.yearly
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Yearly (₹${_formatPrice(widget.plan.yearlyPrice)})',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight:
                                      _cycle == SubscriptionBillingCycle.yearly
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color:
                                      _cycle == SubscriptionBillingCycle.yearly
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Payment Option Selector (Full 100% vs 50% Advance)
                Text(
                  'Payment Option',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isProcessing
                            ? null
                            : () => setState(() {
                                _paymentOption = 'FULL';
                                _couponQuote = null;
                              }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _paymentOption == 'FULL'
                                ? AppColors.subtleGreenBg
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _paymentOption == 'FULL'
                                  ? AppColors.primary
                                  : AppColors.borderLight,
                              width: _paymentOption == 'FULL' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _paymentOption == 'FULL'
                                        ? Remix.checkbox_circle_fill
                                        : Remix.checkbox_blank_circle_line,
                                    size: 16,
                                    color: _paymentOption == 'FULL'
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Full (100%)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_formatPrice(fullPlanTotal)} now',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isProcessing
                            ? null
                            : () => setState(() {
                                _paymentOption = 'ADVANCE';
                                _couponQuote = null;
                              }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _paymentOption == 'ADVANCE'
                                ? AppColors.subtleGreenBg
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _paymentOption == 'ADVANCE'
                                  ? AppColors.primary
                                  : AppColors.borderLight,
                              width: _paymentOption == 'ADVANCE' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _paymentOption == 'ADVANCE'
                                        ? Remix.checkbox_circle_fill
                                        : Remix.checkbox_blank_circle_line,
                                    size: 16,
                                    color: _paymentOption == 'ADVANCE'
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '50% Advance',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_formatPrice(fullPlanTotal * 0.5)} now',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_paymentOption == 'ADVANCE') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Remix.information_fill,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '50% Advance Payment',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• 50% Advance Payment paid before work starts for the first installation.\n• Once the first installation is completed, the remaining 50% second installment is scheduled.\n• Reminder notifications sent prior to the payment due date.',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFF15803D),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Validity Range Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Remix.time_line,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subscription Validity',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Starts ${_formatDate(startDate)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _cycle == SubscriptionBillingCycle.monthly
                              ? '1 Month'
                              : '12 Months',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  enabled: _couponQuote == null && !_applyingCoupon,
                  decoration: InputDecoration(
                    labelText: 'Coupon Code',
                    hintText: 'Enter coupon code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _couponQuote == null
                        ? TextButton(
                            onPressed: _applyingCoupon ? null : _applyCoupon,
                            child: Text(
                              _applyingCoupon ? '...' : 'APPLY',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_couponQuote != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _couponQuote = null;
                          _couponController.clear();
                        });
                      },
                      child: Text(
                        'Remove Coupon',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                // Price Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildPriceRow(
                        'Total Plan Price',
                        '₹${_formatPrice(basePrice)}',
                      ),
                      if (_couponQuote != null) ...[
                        const SizedBox(height: 8),
                        _buildPriceRow(
                          'Coupon ${_couponQuote!['couponCode']}',
                          '-₹${_formatPrice(discountAmount)}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildPriceRow('GST (18%)', '₹${_formatPrice(gstTax)}'),
                      if (isAdvance) ...[
                        const SizedBox(height: 8),
                        _buildPriceRow(
                          'Total with GST',
                          '₹${_formatPrice(fullPlanTotal)}',
                        ),
                        const SizedBox(height: 8),
                        _buildPriceRow(
                          'Remaining on Delivery (50%)',
                          '₹${_formatPrice(remainingBalance)}',
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAdvance
                                ? 'Advance Payable Now'
                                : 'Final Payable Amount',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${_formatPrice(finalAmount)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Payment Method Selector
                const SizedBox(height: 18),
                Text(
                  'Payment Method',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Error state if neither online nor offline is enabled
                if (!_onlinePaymentEnabled && !_offlinePaymentEnabled)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Remix.error_warning_line,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No payment methods are currently configured for this plan. Please contact your administrator.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Payment Options List
                if (_onlinePaymentEnabled || _offlinePaymentEnabled)
                  Column(
                    children: [
                      // 1. Online Payment (Razorpay)
                      if (_onlinePaymentEnabled)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _isProcessing
                              ? null
                              : () => setState(() => _selectedMethod = 'ONLINE'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedMethod == 'ONLINE' ||
                                      _selectedMethod == 'RAZORPAY'
                                  ? AppColors.subtleGreenBg
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedMethod == 'ONLINE' ||
                                        _selectedMethod == 'RAZORPAY'
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: (_selectedMethod == 'ONLINE' ||
                                        _selectedMethod == 'RAZORPAY')
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (_selectedMethod == 'ONLINE' ||
                                          _selectedMethod == 'RAZORPAY')
                                      ? Remix.checkbox_circle_fill
                                      : Remix.checkbox_blank_circle_line,
                                  color: (_selectedMethod == 'ONLINE' ||
                                          _selectedMethod == 'RAZORPAY')
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Online Payment',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Pay securely via UPI, Card, NetBanking (Razorpay)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_onlinePaymentEnabled && _offlinePaymentEnabled)
                        const SizedBox(height: 10),

                      // 2. Offline Payment (Bank Transfer / Cash / UPI)
                      if (_offlinePaymentEnabled)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _isProcessing
                              ? null
                              : () => setState(() => _selectedMethod = 'OFFLINE'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: (_selectedMethod == 'OFFLINE' ||
                                      _selectedMethod == 'CASH')
                                  ? AppColors.subtleGreenBg
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (_selectedMethod == 'OFFLINE' ||
                                        _selectedMethod == 'CASH')
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: (_selectedMethod == 'OFFLINE' ||
                                        _selectedMethod == 'CASH')
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (_selectedMethod == 'OFFLINE' ||
                                          _selectedMethod == 'CASH')
                                      ? Remix.checkbox_circle_fill
                                      : Remix.checkbox_blank_circle_line,
                                  color: (_selectedMethod == 'OFFLINE' ||
                                          _selectedMethod == 'CASH')
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Offline Payment',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Bank Transfer / UPI / Cash payment to admin',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                // Offline payment details card (bank account, upi, instructions, utr/ref, notes)
                if ((_selectedMethod == 'CASH' || _selectedMethod == 'OFFLINE') &&
                    _offlinePaymentEnabled) ...[
                  _buildOfflineDetailsCard(finalAmount),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _offlineRefController,
                    enabled: !_isProcessing,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Transaction Reference / UTR Number (Optional)',
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      hintText: 'e.g. 12-digit UTR or transaction ID',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
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
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBg,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _offlineNotesController,
                    enabled: !_isProcessing,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Payment Remarks / Notes (Optional)',
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      hintText: 'e.g. Paid via Google Pay / Handed cash to office',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
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
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBg,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Proceed Button with Idempotency Lock
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isProcessing ||
                            (!_onlinePaymentEnabled && !_offlinePaymentEnabled))
                        ? null
                        : _handlePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderLight,
                      elevation: 2,
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (!_onlinePaymentEnabled && !_offlinePaymentEnabled)
                                    ? Remix.forbid_2_line
                                    : (((_selectedMethod == 'CASH' ||
                                                _selectedMethod == 'OFFLINE') &&
                                            _offlinePaymentEnabled)
                                        ? Remix.bank_card_line
                                        : Remix.secure_payment_fill),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    (!_onlinePaymentEnabled &&
                                            !_offlinePaymentEnabled)
                                        ? 'Payment Method Unavailable'
                                        : (((_selectedMethod == 'CASH' ||
                                                    _selectedMethod == 'OFFLINE') &&
                                                _offlinePaymentEnabled)
                                            ? 'Submit Offline Request (₹${_formatPrice(finalAmount)})'
                                            : 'Proceed to Payment (₹${_formatPrice(finalAmount)})'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineDetailsCard(double finalAmount) {
    final bankName = _bankDetails?['bankName']?.toString();
    final accNo = _bankDetails?['accountNumber']?.toString();
    final ifsc = _bankDetails?['ifscCode']?.toString();
    final holder = _bankDetails?['accountHolderName']?.toString();
    final upi = _bankDetails?['upiId']?.toString();
    final instructions = _bankDetails?['instructions']?.toString();

    final hasBankInfo = (bankName != null && bankName.isNotEmpty) ||
        (accNo != null && accNo.isNotEmpty) ||
        (ifsc != null && ifsc.isNotEmpty) ||
        (holder != null && holder.isNotEmpty) ||
        (upi != null && upi.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Remix.bank_line, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Offline / Bank Transfer Details',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBankDetailRow(
            'Payable Amount',
            '₹${_formatPrice(finalAmount)}',
            canCopy: true,
          ),
          if (hasBankInfo) ...[
            const Divider(height: 12, color: AppColors.borderLight),
            if (bankName != null && bankName.isNotEmpty)
              _buildBankDetailRow('Bank Name', bankName),
            if (holder != null && holder.isNotEmpty)
              _buildBankDetailRow('Account Holder', holder),
            if (accNo != null && accNo.isNotEmpty)
              _buildBankDetailRow('Account Number', accNo, canCopy: true),
            if (ifsc != null && ifsc.isNotEmpty)
              _buildBankDetailRow('IFSC Code', ifsc, canCopy: true),
            if (upi != null && upi.isNotEmpty)
              _buildBankDetailRow('UPI ID', upi, canCopy: true),
          ],
          if (instructions != null && instructions.isNotEmpty) ...[
            const Divider(height: 12, color: AppColors.borderLight),
            Text(
              instructions,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    AppToast.success(
                      context,
                      '$label copied to clipboard',
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Remix.file_copy_line,
                      size: 14,
                      color: AppColors.primary,
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

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
