import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';

enum PaymentUiState {
  pending,
  processing,
  success,
  failed,
  cancelled,
}

class PaymentStatusView extends StatelessWidget {
  final PaymentUiState state;
  final String title;
  final String message;
  final String? transactionId;
  final double? amount;
  final String currencySymbol;
  final DateTime? timestamp;
  final String? paymentMethod;
  final String? receiptNumber;
  final VoidCallback? onViewReceipt;
  final VoidCallback? onRetry;
  final VoidCallback? onCheckStatus;
  final VoidCallback onDone;

  const PaymentStatusView({
    super.key,
    required this.state,
    required this.title,
    required this.message,
    this.transactionId,
    this.amount,
    this.currencySymbol = '₹',
    this.timestamp,
    this.paymentMethod,
    this.receiptNumber,
    this.onViewReceipt,
    this.onRetry,
    this.onCheckStatus,
    required this.onDone,
  });

  static Future<void> show(
    BuildContext context, {
    required PaymentUiState state,
    required String title,
    required String message,
    String? transactionId,
    double? amount,
    String currencySymbol = '₹',
    DateTime? timestamp,
    String? paymentMethod,
    String? receiptNumber,
    VoidCallback? onViewReceipt,
    VoidCallback? onRetry,
    VoidCallback? onCheckStatus,
    VoidCallback? onDone,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PaymentStatusView(
          state: state,
          title: title,
          message: message,
          transactionId: transactionId,
          amount: amount,
          currencySymbol: currencySymbol,
          timestamp: timestamp,
          paymentMethod: paymentMethod,
          receiptNumber: receiptNumber,
          onViewReceipt: onViewReceipt,
          onRetry: onRetry,
          onCheckStatus: onCheckStatus,
          onDone: onDone ?? () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = state == PaymentUiState.success;
    final isPending = state == PaymentUiState.pending;
    final isProcessing = state == PaymentUiState.processing;
    final isCancelled = state == PaymentUiState.cancelled;

    final Color accentColor = isSuccess
        ? AppColors.primary
        : isPending || isProcessing
        ? Colors.amber.shade700
        : isCancelled
        ? Colors.blueGrey.shade700
        : Colors.red.shade600;

    final Color bgTint = isSuccess
        ? AppColors.subtleGreenBg
        : isPending || isProcessing
        ? Colors.amber.shade50
        : isCancelled
        ? Colors.grey.shade100
        : Colors.red.shade50;

    final IconData icon = isSuccess
        ? Remix.checkbox_circle_fill
        : isPending
        ? Remix.time_fill
        : isProcessing
        ? Remix.shield_check_line
        : isCancelled
        ? Remix.close_circle_line
        : Remix.error_warning_fill;

    final formattedDate = timestamp != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp!.toLocal())
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !isProcessing,
        title: Text(
          'Payment Status',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: bgTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: isProcessing
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: accentColor,
                            ),
                          )
                        : Icon(icon, size: 46, color: accentColor)
                            .animate()
                            .scale(
                              begin: const Offset(0.7, 0.7),
                              end: const Offset(1.0, 1.0),
                              duration: 380.ms,
                              curve: Curves.easeOutBack,
                            ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (amount != null ||
                      transactionId != null ||
                      paymentMethod != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          if (amount != null)
                            _detailRow(
                              'Amount Paid',
                              '$currencySymbol${amount!.toStringAsFixed(2)}',
                              bold: true,
                            ),
                          if (transactionId != null &&
                              transactionId!.isNotEmpty)
                            _detailRow('Transaction ID', transactionId!),
                          if (receiptNumber != null &&
                              receiptNumber!.isNotEmpty)
                            _detailRow('Receipt No', receiptNumber!),
                          if (paymentMethod != null &&
                              paymentMethod!.isNotEmpty)
                            _detailRow('Payment Method', paymentMethod!),
                          _detailRow('Date & Time', formattedDate),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  if (isSuccess && onViewReceipt != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onViewReceipt,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Remix.file_text_line, size: 18),
                        label: Text(
                          'View Receipt',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((isPending) && onCheckStatus != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onCheckStatus,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Remix.refresh_line, size: 18),
                        label: Text(
                          'Check Payment Status',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((state == PaymentUiState.failed ||
                          state == PaymentUiState.cancelled) &&
                      onRetry != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Try Again',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isProcessing)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: onDone,
                        style: FilledButton.styleFrom(
                          backgroundColor: isSuccess
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isSuccess ? 'Continue' : 'Back',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
