import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/roles/customer/services/customer_subscription_service.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/customer_subscription_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/proposal_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/checkout_bottom_sheet.dart';

class CustomerProposalsView extends ConsumerStatefulWidget {
  const CustomerProposalsView({super.key});

  @override
  ConsumerState<CustomerProposalsView> createState() =>
      _CustomerProposalsViewState();
}

class _CustomerProposalsViewState extends ConsumerState<CustomerProposalsView> {
  int? _openingPdfId;

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso.isEmpty ? '—' : iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _openPdf(CustomerProposalRecord proposal) async {
    if (_openingPdfId != null) return;
    setState(() => _openingPdfId = proposal.id);
    try {
      await ref
          .read(customerSubscriptionServiceProvider)
          .downloadAndOpenProposalPdf(proposal.id);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not open proposal PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _openingPdfId = null);
    }
  }

  Future<void> _buyPlan(CustomerProposalRecord proposal) async {
    final plan = proposal.toCheckoutPlan();
    final order = await CheckoutBottomSheet.show(
      context: context,
      plan: plan,
      cycle: proposal.billingCycle,
      proposalId: proposal.id,
    );
    if (order != null && mounted) {
      await ref.read(customerProposalsProvider.notifier).refresh();
      refreshCustomerPlansData(ref);
    }
  }

  void _showProposalDetails(CustomerProposalRecord p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.planName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.proposalNo} • ${p.billingCycle.label} • ₹${p.agreedPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    p.description,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (p.features.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Included Services & Deliverables',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...p.features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(Icons.check_circle,
                                size: 14, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.displayLine,
                              style: GoogleFonts.outfit(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (p.terms.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Terms & Conditions',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.terms,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (!p.alreadyPaid)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _buyPlan(p);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Buy Plan'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(customerProposalsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Proposal',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Remix.refresh_line, color: AppColors.textPrimary),
            onPressed: () =>
                ref.read(customerProposalsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: proposalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Remix.error_warning_line,
                    size: 40, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Unable to load your proposals.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(customerProposalsProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (proposals) {
          if (proposals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No proposals have been sent to your account yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(customerProposalsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: proposals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final p = proposals[index];
                final isPdfBusy = _openingPdfId == p.id;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.planName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.alreadyPaid
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              p.alreadyPaid ? 'PAID / ACTIVE' : p.status,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: p.alreadyPaid
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.proposalNo} • ${_formatDate(p.proposalDate)} • By ${p.createdByName}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹${p.agreedPrice.toStringAsFixed(0)} / ${p.billingCycle.label}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (p.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          p.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (p.features.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...p.features.take(4).map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 3),
                                      child: Icon(Icons.check_circle,
                                          size: 13, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        f.displayLine,
                                        style: GoogleFonts.outfit(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showProposalDetails(p),
                              child: const Text('View Proposal'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isPdfBusy ? null : () => _openPdf(p),
                              icon: const Icon(Remix.file_pdf_2_line, size: 16),
                              label: Text(isPdfBusy ? 'Opening...' : 'Download PDF'),
                            ),
                          ),
                        ],
                      ),
                      if (!p.alreadyPaid) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _buyPlan(p),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Buy Plan'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
