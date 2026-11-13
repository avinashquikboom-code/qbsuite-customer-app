import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_document_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/invoice_preview_dialog.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/plan_feature_item.dart';

class CustomerOrderDetailsView extends ConsumerWidget {
  final CustomerOrder order;

  const CustomerOrderDetailsView({super.key, required this.order});

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

  Future<void> _handleReceiptAction({
    required BuildContext context,
    required WidgetRef ref,
    required String receiptId,
    required String title,
    required bool openAfterDownload,
  }) async {
    try {
      AppToast.info(
        context,
        openAfterDownload ? 'Opening $title...' : 'Downloading $title...',
        title: 'Please wait',
      );
      final docService = ref.read(customerDocumentServiceProvider);
      await docService.downloadReceipt(
        receiptId: receiptId,
        orderId: order.orderNumber,
        openAfterDownload: openAfterDownload,
      );
      if (context.mounted) {
        AppToast.success(
          context,
          openAfterDownload
              ? '$title opened successfully.'
              : '$title downloaded to device.',
          title: 'Success',
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        AppToast.error(
          context,
          msg.isNotEmpty
              ? msg
              : 'Unable to download the document. Please try again.',
          title: 'Download Failed',
        );
      }
    }
  }

  Future<void> _handleInvoiceAction({
    required BuildContext context,
    required WidgetRef ref,
    required String invoiceId,
    String? invoiceNumber,
    required bool openAfterDownload,
  }) async {
    try {
      AppToast.info(
        context,
        openAfterDownload
            ? 'Opening Tax Invoice...'
            : 'Downloading Tax Invoice...',
        title: 'Please wait',
      );
      final docService = ref.read(customerDocumentServiceProvider);
      await docService.downloadInvoice(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        orderId: order.orderNumber,
        openAfterDownload: openAfterDownload,
      );
      if (context.mounted) {
        AppToast.success(
          context,
          openAfterDownload
              ? 'Tax Invoice opened successfully.'
              : 'Tax Invoice downloaded to device.',
          title: 'Success',
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        AppToast.error(
          context,
          msg.isNotEmpty
              ? msg
              : 'Unable to download the document. Please try again.',
          title: 'Download Failed',
        );
      }
    }
  }

  /*
  Future<void> _handleAgreementAction({
    required BuildContext context,
    required WidgetRef ref,
    required bool openAfterDownload,
  }) async {
    try {
      AppToast.info(
        context,
        openAfterDownload
            ? 'Opening Service Agreement...'
            : 'Downloading Service Agreement...',
        title: 'Please wait',
      );
      final docService = ref.read(customerDocumentServiceProvider);
      final paymentId = order.id.trim().isNotEmpty
          ? order.id.trim()
          : order.orderNumber.trim();
      await docService.downloadAgreement(
        paymentId: paymentId,
        invoiceId: order.invoiceId,
        orderId: order.orderNumber,
        openAfterDownload: openAfterDownload,
      );
      if (context.mounted) {
        AppToast.success(
          context,
          openAfterDownload
              ? 'Service Agreement opened successfully.'
              : 'Service Agreement downloaded to device.',
          title: 'Success',
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        AppToast.error(
          context,
          msg.isNotEmpty
              ? msg
              : 'Unable to download agreement. Please try again.',
          title: 'Download Failed',
        );
      }
    }
  }
  */

  Future<void> _handleInvoiceShare({
    required BuildContext context,
    required WidgetRef ref,
    required String invoiceId,
    String? invoiceNumber,
  }) async {
    try {
      AppToast.info(
        context,
        'Preparing Tax Invoice for sharing...',
        title: 'Please wait',
      );
      final docService = ref.read(customerDocumentServiceProvider);
      final file = await docService.downloadInvoice(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        orderId: order.orderNumber,
        openAfterDownload: false,
      );
      final name = invoiceNumber ?? invoiceId;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Tax Invoice #$name',
          text: 'Tax Invoice #$name for ${order.planName}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        AppToast.error(
          context,
          msg.isNotEmpty ? msg : 'Unable to share Tax Invoice.',
          title: 'Share Failed',
        );
      }
    }
  }

  /*
  Future<void> _handleAgreementShare({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      AppToast.info(
        context,
        'Preparing Service Agreement for sharing...',
        title: 'Please wait',
      );
      final docService = ref.read(customerDocumentServiceProvider);
      final paymentId = order.id.trim().isNotEmpty
          ? order.id.trim()
          : order.orderNumber.trim();
      final file = await docService.downloadAgreement(
        paymentId: paymentId,
        invoiceId: order.invoiceId,
        orderId: order.orderNumber,
        openAfterDownload: false,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Service Agreement – ${order.orderNumber}',
          text: 'Service Agreement for ${order.planName} (${order.orderNumber})',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        AppToast.error(
          context,
          msg.isNotEmpty ? msg : 'Unable to share Service Agreement.',
          title: 'Share Failed',
        );
      }
    }
  }
  */

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid = order.isPaid;
    final totalAmount = order.totalAmount;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Order Details',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.printer_line, color: AppColors.textPrimary),
            onPressed: () {
              if (order.invoiceAvailable && order.invoiceId != null) {
                _handleInvoiceAction(
                  context: context,
                  ref: ref,
                  invoiceId: order.invoiceId!,
                  invoiceNumber: order.invoiceNumber,
                  openAfterDownload: true,
                );
              } else if (order.receiptAvailable) {
                final rId = order.receiptNumber ?? order.receiptId ?? order.id;
                _handleReceiptAction(
                  context: context,
                  ref: ref,
                  receiptId: rId,
                  title: 'Payment Receipt',
                  openAfterDownload: true,
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => InvoicePreviewDialog(order: order),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Status Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          order.orderNumber,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.primaryLight
                                : (order.isPartiallyPaid
                                      ? const Color(0xFFEFF6FF)
                                      : AppColors.warning.withValues(
                                          alpha: 0.12,
                                        )),
                            borderRadius: BorderRadius.circular(8),
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
                                      : (order.isPartiallyPaid
                                            ? const Color(0xFF2563EB)
                                            : AppColors.warning),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  isPaid
                                      ? 'Payment Paid'
                                      : (order.isPartiallyPaid
                                            ? 'Partially Paid'
                                            : 'Payment Pending'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? AppColors.primaryDark
                                        : (order.isPartiallyPaid
                                              ? const Color(0xFF2563EB)
                                              : AppColors.warning),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 14),
                  _buildMetaRow('Plan / Service', order.planName),
                  const SizedBox(height: 8),
                  _buildMetaRow('Billing Cycle', order.billingCycle.label),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    'Purchase Date',
                    _formatDate(order.purchaseDate),
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    'Activation Date',
                    _formatDate(order.activationDate),
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow('Expiry Date', _formatDate(order.expiryDate)),
                  const SizedBox(height: 8),
                  _buildMetaRow('Payment Method', order.paymentMethod),
                  if (order.transactionId != null) ...[
                    const SizedBox(height: 8),
                    _buildMetaRow('Transaction ID', order.transactionId!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Summary Section
            Container(
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
                    'PAYMENT SUMMARY',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    'Total Amount',
                    '₹${_formatPrice(totalAmount)}',
                  ),
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    'Paid Amount',
                    '₹${_formatPrice(order.paidAmount > 0 ? order.paidAmount : (isPaid ? totalAmount : 0))}',
                  ),
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    'Remaining Amount',
                    '₹${_formatPrice(order.remainingAmount)}',
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    'Payment Type',
                    order.installments.length > 1
                        ? '2 Installments (50% + 50%)'
                        : 'Full Payment (100%)',
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    'Payment Status',
                    isPaid
                        ? 'FULLY PAID'
                        : (order.isPartiallyPaid
                              ? 'PARTIALLY PAID'
                              : 'PENDING'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Documents Access Section
            Container(
              padding: const EdgeInsets.all(18),
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
                      Expanded(
                        child: Text(
                          'DOCUMENTS & RECEIPTS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Remix.file_shield_2_line,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Installment receipts list
                  if (order.installments.isNotEmpty) ...[
                    ...order.installments.map((inst) {
                      final receiptNo =
                          inst.receiptNumber ??
                          inst.receiptId ??
                          order.receiptNumber ??
                          order.receiptId ??
                          order.id;
                      return _buildDocumentCard(
                        context: context,
                        title: inst.title,
                        subtitle: inst.receiptAvailable
                            ? (inst.receiptNumber ?? 'Receipt Issued')
                            : (inst.lockReason ?? 'Available after payment'),
                        isAvailable: inst.receiptAvailable,
                        icon: Remix.receipt_line,
                        onView: () {
                          _handleReceiptAction(
                            context: context,
                            ref: ref,
                            receiptId: receiptNo,
                            title: inst.title,
                            openAfterDownload: true,
                          );
                        },
                        onDownload: () {
                          _handleReceiptAction(
                            context: context,
                            ref: ref,
                            receiptId: receiptNo,
                            title: inst.title,
                            openAfterDownload: false,
                          );
                        },
                      );
                    }),
                  ] else ...[
                    _buildDocumentCard(
                      context: context,
                      title: 'Payment Receipt',
                      subtitle: order.receiptAvailable
                          ? (order.receiptNumber ?? 'Receipt Available')
                          : (order.receiptLockReason ?? 'Payment Pending'),
                      isAvailable: order.receiptAvailable,
                      icon: Remix.receipt_line,
                      onView: () {
                        final rId =
                            order.receiptNumber ?? order.receiptId ?? order.id;
                        _handleReceiptAction(
                          context: context,
                          ref: ref,
                          receiptId: rId,
                          title: 'Payment Receipt',
                          openAfterDownload: true,
                        );
                      },
                      onDownload: () {
                        final rId =
                            order.receiptNumber ?? order.receiptId ?? order.id;
                        _handleReceiptAction(
                          context: context,
                          ref: ref,
                          receiptId: rId,
                          title: 'Payment Receipt',
                          openAfterDownload: false,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Final Tax Invoice Card
                  _buildDocumentCard(
                    context: context,
                    title: 'Final Tax Invoice',
                    subtitle: order.invoiceAvailable
                        ? (order.invoiceNumber ?? 'Tax Invoice Issued')
                        : (order.invoiceLockReason ??
                              'Available after complete payment'),
                    isAvailable: order.invoiceAvailable,
                    icon: Remix.bill_line,
                    onView: () {
                      if (order.invoiceId != null) {
                        _handleInvoiceAction(
                          context: context,
                          ref: ref,
                          invoiceId: order.invoiceId!,
                          invoiceNumber: order.invoiceNumber,
                          openAfterDownload: true,
                        );
                      }
                    },
                    onDownload: () {
                      if (order.invoiceId != null) {
                        _handleInvoiceAction(
                          context: context,
                          ref: ref,
                          invoiceId: order.invoiceId!,
                          invoiceNumber: order.invoiceNumber,
                          openAfterDownload: false,
                        );
                      }
                    },
                    onShare: () {
                      if (order.invoiceId != null) {
                        _handleInvoiceShare(
                          context: context,
                          ref: ref,
                          invoiceId: order.invoiceId!,
                          invoiceNumber: order.invoiceNumber,
                        );
                      }
                    },
                  ),

                  // Service Agreement card commented out temporarily
                  /*
                  if (isPaid) ...[
                    const SizedBox(height: 6),
                    _buildDocumentCard(
                      context: context,
                      title: 'Service Agreement',
                      subtitle:
                          'Service Agreement PDF (${order.orderNumber})',
                      isAvailable: true,
                      icon: Remix.file_paper_2_line,
                      onView: () {
                        _handleAgreementAction(
                          context: context,
                          ref: ref,
                          openAfterDownload: true,
                        );
                      },
                      onDownload: () {
                        _handleAgreementAction(
                          context: context,
                          ref: ref,
                          openAfterDownload: false,
                        );
                      },
                      onShare: () {
                        _handleAgreementShare(
                          context: context,
                          ref: ref,
                        );
                      },
                    ),
                  ],
                  */
                ],
              ),
            ),

            if (order.features.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
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
                      'PLAN FEATURES INCLUDED',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.features.map((f) => PlanFeatureItem(text: f)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.end,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isAvailable,
    required IconData icon,
    required VoidCallback onView,
    required VoidCallback onDownload,
    VoidCallback? onShare,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAvailable ? AppColors.borderLight : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isAvailable
                  ? AppColors.primaryLight
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAvailable ? icon : Remix.lock_line,
              color: isAvailable
                  ? AppColors.primaryDark
                  : AppColors.textPlaceholder,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable ? subtitle : '🔒 $subtitle',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isAvailable
                        ? AppColors.textSecondary
                        : AppColors.textPlaceholder,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isAvailable) ...[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: onView,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: onDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.download_2_line,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Save',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onShare != null) ...[
                      const SizedBox(width: 4),
                      OutlinedButton(
                        onPressed: onShare,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Remix.share_forward_line,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Locked',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
