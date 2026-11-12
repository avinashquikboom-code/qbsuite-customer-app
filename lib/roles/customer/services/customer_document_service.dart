import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';

final customerDocumentServiceProvider = Provider<CustomerDocumentService>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerDocumentService(apiClient: apiClient);
});

class CustomerDocumentService {
  final ApiClient _apiClient;

  CustomerDocumentService({required ApiClient apiClient})
    : _apiClient = apiClient;

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
  }

  Future<String> _getStorageDirectoryPath() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDocDir.path}/documents');
      if (!docsDir.existsSync()) {
        docsDir.createSync(recursive: true);
      }
      return docsDir.path;
    } catch (_) {
      final tempDir = await getTemporaryDirectory();
      return tempDir.path;
    }
  }

  /// Download and optionally open a Payment Receipt PDF
  Future<File> downloadReceipt({
    required String receiptId,
    String? orderId,
    bool openAfterDownload = false,
  }) async {
    final cleanId = receiptId.trim();
    if (cleanId.isEmpty) {
      throw Exception('Invalid receipt ID');
    }

    final endpoint = '/receipts/$cleanId/download';
    final bytes = await _apiClient.downloadFileBytes(
      endpoint,
      documentType: 'RECEIPT',
      documentId: cleanId,
      orderId: orderId,
    );

    final dirPath = await _getStorageDirectoryPath();
    final safeFileName = 'receipt_${_sanitizeFileName(cleanId)}.pdf';
    final filePath = '$dirPath/$safeFileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw Exception('Failed to save receipt file to storage.');
    }

    debugPrint('[DOCUMENT_DEBUG]');
    debugPrint('download path: $filePath');
    debugPrint('file size: ${file.lengthSync()} bytes');

    if (openAfterDownload) {
      await OpenFilex.open(filePath);
    }

    return file;
  }

  /// Download and optionally open a Final Tax Invoice PDF
  Future<File> downloadInvoice({
    required String invoiceId,
    String? invoiceNumber,
    String? orderId,
    bool openAfterDownload = false,
  }) async {
    final cleanId = invoiceId.trim();
    if (cleanId.isEmpty) {
      throw Exception('Invalid invoice ID');
    }

    final endpoint = '/invoices/$cleanId/download';
    final bytes = await _apiClient.downloadFileBytes(
      endpoint,
      documentType: 'INVOICE',
      documentId: cleanId,
      orderId: orderId,
    );

    final dirPath = await _getStorageDirectoryPath();
    final nameKey = invoiceNumber != null && invoiceNumber.isNotEmpty
        ? invoiceNumber
        : cleanId;
    final safeFileName = 'invoice_${_sanitizeFileName(nameKey)}.pdf';
    final filePath = '$dirPath/$safeFileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw Exception('Failed to save invoice file to storage.');
    }

    debugPrint('[DOCUMENT_DEBUG]');
    debugPrint('download path: $filePath');
    debugPrint('file size: ${file.lengthSync()} bytes');

    if (openAfterDownload) {
      await OpenFilex.open(filePath);
    }

    return file;
  }

  /// Download and optionally open a Service Agreement PDF
  Future<File> downloadAgreement({
    String? paymentId,
    String? invoiceId,
    String? orderId,
    bool openAfterDownload = false,
  }) async {
    final cleanPaymentId = paymentId?.trim() ?? '';
    final cleanInvoiceId = invoiceId?.trim() ?? '';

    if (cleanPaymentId.isEmpty && cleanInvoiceId.isEmpty) {
      throw Exception('Payment or Invoice ID is missing. Cannot generate agreement.');
    }

    // Agreement is generated from the payment row.
    // ORD-PAY-78 is the display key; PaymentHistory.id is 78.
    // Do not fall through to /invoices/:id — that id is not this order's agreement.
    final ordPay = RegExp(r'^ORD-PAY-(\d+)$', caseSensitive: false)
        .firstMatch(cleanPaymentId);
    final resolvedPaymentId = ordPay != null
        ? ordPay.group(1)!
        : (cleanPaymentId.isNotEmpty ? cleanPaymentId : cleanInvoiceId);
    final encodedId = Uri.encodeComponent(resolvedPaymentId);
    final endpoint = '/payments/$encodedId/agreement/download';
    debugPrint('[AGREEMENT_DEBUG] method: GET');
    debugPrint('[AGREEMENT_DEBUG] path: $endpoint');
    debugPrint('[AGREEMENT_DEBUG] orderId: ${orderId ?? ""}');
    debugPrint('[AGREEMENT_DEBUG] agreementId: $resolvedPaymentId');
    debugPrint('[AGREEMENT_DEBUG] paymentKey: $cleanPaymentId');

    final bytes = await _apiClient.downloadFileBytes(
      endpoint,
      documentType: 'AGREEMENT',
      documentId: resolvedPaymentId,
      orderId: orderId,
    );
    final docId = resolvedPaymentId;

    if (bytes.isEmpty) {
      throw Exception('Failed to download agreement file.');
    }

    final dirPath = await _getStorageDirectoryPath();
    final safeFileName = 'agreement_${_sanitizeFileName(orderId ?? docId)}.pdf';
    final filePath = '$dirPath/$safeFileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw Exception('Failed to save agreement file to storage.');
    }

    debugPrint('[DOCUMENT_DEBUG]');
    debugPrint('download path: $filePath');
    debugPrint('file size: ${file.lengthSync()} bytes');

    if (openAfterDownload) {
      await OpenFilex.open(filePath);
    }

    return file;
  }
}
