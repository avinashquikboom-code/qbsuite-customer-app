import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
// import 'package:quickboom_crm_customer/roles/customer/services/customer_document_service.dart';
import 'invoice_preview_dialog.dart';

class OrderSummaryCard extends ConsumerStatefulWidget {
  final CustomerOrder order;
  final VoidCallback onTap;

  const OrderSummaryCard({super.key, required this.order, required this.onTap});

  @override
  ConsumerState<OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends ConsumerState<OrderSummaryCard> {
  // bool _isDownloadingAgreement = false;

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

  void _showInvoice(BuildContext context) {
    final docTitle = widget.order.invoiceAvailable
        ? 'TAX INVOICE'
        : 'PAYMENT RECEIPT';
    final docNumber = widget.order.invoiceAvailable
        ? (widget.order.invoiceNumber ?? 'INV-${widget.order.id}')
        : (widget.order.receiptNumber ??
              widget.order.receiptId ??
              'REC-${widget.order.id}');
    final displayAmount = widget.order.isPartiallyPaid
        ? widget.order.paidAmount
        : widget.order.totalAmount;
    showDialog(
      context: context,
      builder: (ctx) => InvoicePreviewDialog(
        order: widget.order,
        documentTitle: docTitle,
        documentNumber: docNumber,
        displayAmount: displayAmount,
      ),
    );
  }

  void printInvoice(BuildContext context) {
    AppToast.success(
      context,
      'Sending invoice ${widget.order.orderNumber} to printer...',
      title: 'Printing Invoice',
    );
  }

  /*
  Future<void> _downloadAgreement() async {
    if (_isDownloadingAgreement) return;

    setState(() {
      _isDownloadingAgreement = true;
    });

    try {
      final docService = ref.read(customerDocumentServiceProvider);
      
      final paymentId = widget.order.id.trim().isNotEmpty
          ? widget.order.id.trim()
          : widget.order.orderNumber.trim();
      if (paymentId.isEmpty) {
        throw Exception('Order ID is missing. Cannot generate agreement.');
      }

      await docService.downloadAgreement(
        paymentId: paymentId,
        invoiceId: widget.order.invoiceId,
        orderId: widget.order.orderNumber,
        openAfterDownload: true,
      );
      if (mounted) {
        AppToast.success(
          context,
          'Agreement downloaded and opened successfully',
          title: 'Success',
        );
      }
    } catch (e) {
      debugPrint('[DOCUMENT_DEBUG] Agreement download error: $e');
      if (mounted) {
        final message = e.toString().toLowerCase();
        final unavailable = message.contains('document not found') ||
            message.contains('not available');
        AppToast.error(
          context,
          unavailable
              ? 'Agreement is not available for this order.'
              : 'Could not generate or download agreement. Please try again.',
          title: 'Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAgreement = false;
        });
      }
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final bool isPaid = widget.order.isPaid;
    final order = widget.order;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Row: Order ID & Status Badge
                Row(
                  children: [
                    const Icon(
                      Remix.file_paper_2_line,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.primaryLight
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? AppColors.primaryDark
                                  : AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPaid ? 'Paid' : 'Pending',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? AppColors.primaryDark
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),

                // 2. Plan Name & Billing Cycle
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.planName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pillBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.billingCycle.label,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3. Purchase & Expiry Dates Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Date',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(order.purchaseDate),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: AppColors.borderLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry Date',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(order.expiryDate),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Total Amount & Compact Preview Icon Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_formatPrice(order.totalAmount)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Agreement button commented out temporarily
                    /*
                    if (isPaid) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: _isDownloadingAgreement
                              ? null
                              : _downloadAgreement,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isDownloadingAgreement
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Row(
                                  children: [
                                    const Icon(
                                      Remix.file_paper_2_line,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Agreement',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                    */
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => _showInvoice(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Preview',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
