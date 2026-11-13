import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../services/customer_ai_studio_service.dart';
import '../viewmodels/customer_ai_studio_viewmodel.dart';

/// Opens the bottom sheet modal for purchasing AI credits
void showAiCreditTopUpModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const AiCreditTopUpModal(),
  );
}

/// Modal for purchasing AI credits
class AiCreditTopUpModal extends ConsumerStatefulWidget {
  const AiCreditTopUpModal({super.key});

  @override
  ConsumerState<AiCreditTopUpModal> createState() => _AiCreditTopUpModalState();
}

class _AiCreditTopUpModalState extends ConsumerState<AiCreditTopUpModal> {
  int _selectedCredits = 25;
  double _selectedPrice = 225.0;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _packs = [
    {'credits': 10, 'price': 100.0, 'label': 'Starter'},
    {'credits': 25, 'price': 225.0, 'label': 'Popular (10% OFF)'},
    {'credits': 50, 'price': 400.0, 'label': 'Growth (20% OFF)'},
    {'credits': 100, 'price': 750.0, 'label': 'Agency (25% OFF)'},
  ];

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    final service = ref.read(customerAiStudioServiceProvider);

    try {
      final orderData = await service.createCreditOrder(
        credits: _selectedCredits,
        amount: _selectedPrice,
      );

      // Verify payment with simulated confirmation for dev/staging
      final fakePaymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
      final orderId =
          orderData?['orderId'] ??
          'order_${DateTime.now().millisecondsSinceEpoch}';

      final verified = await service.verifyCreditPayment(
        razorpayPaymentId: fakePaymentId,
        razorpayOrderId: orderId,
        razorpaySignature: 'auto_verified_sig',
        credits: _selectedCredits,
      );

      if (verified) {
        await ref.read(customerAiWalletProvider.notifier).refresh();
        if (mounted) {
          Navigator.pop(context);
          AppToast.success(
            context,
            'Successfully added $_selectedCredits AI credits!',
            title: 'Top-Up Successful',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          'Failed to purchase credits. Please try again.',
          title: 'Purchase Failed',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top-Up AI Credits',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._packs.map((p) {
              final isSelected = _selectedCredits == p['credits'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCredits = p['credits'] as int;
                    _selectedPrice = p['price'] as double;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['credits']} Credits',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            p['label'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${(p['price'] as double).toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isProcessing ? null : _handlePurchase,
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
                        'Pay ₹${_selectedPrice.toStringAsFixed(0)} & Add Credits',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
