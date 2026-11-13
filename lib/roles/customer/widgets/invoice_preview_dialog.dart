import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_invoice_model.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_document_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_profile_viewmodel.dart';

class InvoicePreviewDialog extends ConsumerWidget {
  final CustomerOrder? order;
  final CustomerInvoice? invoice;
  final String? documentTitle;
  final String? documentNumber;
  final double? displayAmount;
  final String? downloadUrl;

  const InvoicePreviewDialog({
    super.key,
    this.order,
    this.invoice,
    this.documentTitle,
    this.documentNumber,
    this.displayAmount,
    this.downloadUrl,
  }) : assert(
         order != null || invoice != null,
         'Either order or invoice must be provided',
       );

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isPartial =
        order?.isPartiallyPaid == true ||
        (order?.invoiceUrl != null && order!.invoiceUrl!.startsWith('REC-')) ||
        (documentNumber != null && documentNumber!.startsWith('REC-'));

    final String docTitle =
        documentTitle ?? (isPartial ? 'PAYMENT RECEIPT' : 'TAX INVOICE');
    final String docNumber =
        documentNumber ??
        (invoice?.invoiceNumber ??
            order?.invoiceNumber ??
            order?.receiptNumber ??
            (isPartial
                ? 'REC-2026-${order?.id.padLeft(6, '0')}'
                : 'INV-2026-${order?.id.padLeft(6, '0')}'));

    final total =
        displayAmount ??
        invoice?.totalAmount ??
        (isPartial && (order?.paidAmount ?? 0) > 0
            ? order!.paidAmount
            : (order?.totalAmount ?? 0.0));

    final basePrice = invoice?.subTotal ?? (total / 1.18);
    final tax = invoice?.taxAmount ?? (total - basePrice);

    final customerProfile = ref.watch(customerProfileProvider).asData?.value;
    final clientName =
        (invoice?.clientName.isNotEmpty == true &&
            invoice?.clientName != 'General Client')
        ? invoice!.clientName
        : (customerProfile?.personFullName.isNotEmpty == true
              ? customerProfile!.personFullName
              : (customerProfile?.name.isNotEmpty == true
                    ? customerProfile!.name
                    : 'Valued Client'));

    final clientAddress = [
      if (customerProfile?.address != null &&
          customerProfile!.address!.trim().isNotEmpty)
        customerProfile.address!.trim(),
      if (customerProfile?.city != null &&
          customerProfile!.city!.trim().isNotEmpty)
        customerProfile.city!.trim(),
      if (customerProfile?.state != null &&
          customerProfile!.state!.trim().isNotEmpty)
        customerProfile.state!.trim(),
      if (customerProfile?.country != null &&
          customerProfile!.country!.trim().isNotEmpty)
        customerProfile.country!.trim(),
    ].join(', ');
    final displayAddress = clientAddress.isNotEmpty
        ? clientAddress
        : 'Mumbai, Maharashtra, India';

    final isPaid = invoice?.isPaid == true || order?.isPaid == true;

    final purchaseDate =
        invoice?.issueDate ?? order?.purchaseDate ?? DateTime.now();
    final DateTime? planStartDate =
        invoice?.activationDate ?? order?.activationDate;
    final DateTime? planEndDate = invoice?.expiryDate ?? order?.expiryDate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: QuikBoom Logo & Tax Invoice Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('assets/images/app_logo.png', width: 36, height: 36, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QB Suite Customer',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            docTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Remix.close_line, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 16),

              // Company & Order Meta
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BILLED TO',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clientName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          displayAddress,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice != null ? 'INVOICE NUMBER' : 'ORDER NUMBER',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        docNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (order?.orderNumber != null)
                        Text(
                          'Ref: ${order!.orderNumber}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Purchase Date: ${_formatDate(purchaseDate)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (planStartDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Plan Start: ${_formatDate(planStartDate)}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Itemized Table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'PLAN NAME / ITEM',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            'QTY',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            'UNIT PRICE',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            'TOTAL',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),
                    if (invoice?.planType?.toUpperCase() == 'CUSTOM' &&
                        (invoice?.planName ?? '').isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CUSTOM PLAN: ${invoice!.planName}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ..._buildPreviewLineItems(invoice, order, basePrice),
                    if (planStartDate != null && planEndDate != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Validity: ${_formatDate(planStartDate)} → ${_formatDate(planEndDate)}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),

                    // Subtotal
                    _buildRow('Subtotal', '₹${_formatPrice(basePrice)}'),
                    const SizedBox(height: 6),
                    if ((invoice?.discount ?? 0) > 0.005) ...[
                      _buildRow(
                        'Discount',
                        '- ₹${_formatPrice(invoice!.discount)}',
                      ),
                      const SizedBox(height: 6),
                    ],
                    _buildRow('GST (18%)', '₹${_formatPrice(tax)}'),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 10),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPaid ? 'Total Paid' : 'Total Amount',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '₹${_formatPrice(total)}',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payment Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.primaryLight
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid ? Remix.checkbox_circle_fill : Remix.time_fill,
                      color: isPaid
                          ? AppColors.primaryDark
                          : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaid
                                ? 'Payment Status: PAID'
                                : 'Status: ${invoice?.status ?? order?.paymentStatus ?? 'PENDING'}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? AppColors.primaryDark
                                  : const Color(0xFFB45309),
                            ),
                          ),
                          if (order?.transactionId != null)
                            Text(
                              'Transaction ID: ${order!.transactionId}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons Row (Download PDF & Agreement)
              if (ref
                  .watch(permissionManagerProvider)
                  .customerCan('CUSTOMER_INVOICES', 'DOWNLOAD'))
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final docService = ref.read(
                                customerDocumentServiceProvider,
                              );
                              final isReceipt =
                                  (docTitle.contains('RECEIPT') ||
                                  docNumber.startsWith('REC-'));
                              AppToast.info(
                                context,
                                'Downloading and opening document...',
                                title: 'Please wait',
                              );
                              if (isReceipt) {
                                final targetReceiptId =
                                    order?.receiptNumber ??
                                    order?.receiptId ??
                                    docNumber;
                                await docService.downloadReceipt(
                                  receiptId: targetReceiptId,
                                  orderId: order?.orderNumber,
                                  openAfterDownload: true,
                                );
                              } else {
                                final invId =
                                    invoice?.id ?? order?.invoiceId ?? docNumber;
                                await docService.downloadInvoice(
                                  invoiceId: invId,
                                  invoiceNumber: docNumber,
                                  orderId: order?.orderNumber,
                                  openAfterDownload: true,
                                );
                              }
                              if (context.mounted) {
                                AppToast.success(
                                  context,
                                  'Document saved and opened successfully.',
                                  title: 'Download Successful',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                final msg = e
                                    .toString()
                                    .replaceAll('Exception:', '')
                                    .trim();
                                AppToast.error(
                                  context,
                                  msg.isNotEmpty
                                      ? msg
                                      : 'Unable to download the document. Please try again.',
                                  title: 'Download Failed',
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Remix.download_2_line,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Download PDF',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Agreement button commented out temporarily
                    /*
                    if (isPaid && (order?.hasAgreement == true || invoice?.hasAgreement == true)) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final docService = ref.read(
                                  customerDocumentServiceProvider,
                                );
                                AppToast.info(
                                  context,
                                  'Downloading and opening Agreement...',
                                  title: 'Please wait',
                                );
                                final targetPaymentId =
                                    (order?.id.trim().isNotEmpty == true)
                                        ? order!.id.trim()
                                        : order?.orderNumber.trim();
                                final targetInvoiceId = invoice?.id;
                                if ((targetPaymentId == null || targetPaymentId.isEmpty) &&
                                    (targetInvoiceId == null || targetInvoiceId.isEmpty)) {
                                  throw Exception('Order payment ID is missing. Cannot generate agreement.');
                                }
                                await docService.downloadAgreement(
                                  paymentId: targetPaymentId,
                                  invoiceId: targetInvoiceId,
                                  orderId: order?.orderNumber ?? invoice?.invoiceNumber,
                                  openAfterDownload: true,
                                );
                                if (context.mounted) {
                                  AppToast.success(
                                    context,
                                    'Agreement opened successfully.',
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppToast.error(
                                    context,
                                    'Unable to download Agreement. Please try again.',
                                    title: 'Download Failed',
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Remix.file_paper_2_line,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Agreement',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary, width: 1.2),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    */
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPreviewLineItems(
    CustomerInvoice? invoice,
    CustomerOrder? order,
    double fallbackAmount,
  ) {
    final items = invoice?.lineItems ?? const <InvoiceLineItem>[];
    if (items.isNotEmpty) {
      return [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildLineItemRow(
            i + 1,
            items[i].name,
            items[i].quantity,
            items[i].unitPrice,
            items[i].total,
          ),
        ],
      ];
    }

    final fallbackName =
        (invoice?.planName != null && invoice!.planName!.isNotEmpty)
        ? invoice.planName!
        : (order != null
              ? '${order.planName} (${order.billingCycle.label})'
              : 'CRM Subscription / Business Plan');
    return [
      _buildLineItemRow(1, fallbackName, 1, fallbackAmount, fallbackAmount),
    ];
  }

  Widget _buildLineItemRow(
    int index,
    String name,
    int quantity,
    double unitPrice,
    double total,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            '$index. $name',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '₹${_formatPrice(unitPrice)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '₹${_formatPrice(total)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
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
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
