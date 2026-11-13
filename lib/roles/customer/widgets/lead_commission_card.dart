import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';

/// Commission Card:
/// Shows upcoming commission if eligible and > 0.
/// Does NOT show ₹0 when no commission exists.
/// Reads directly from backend commission data (no Flutter-side calculation).
class LeadCommissionCard extends StatelessWidget {
  final LeadModel lead;

  const LeadCommissionCard({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    if (lead.upcomingCommission == null || lead.upcomingCommission! <= 0) {
      return const SizedBox.shrink();
    }

    final intVal = lead.upcomingCommission!.round();
    final amountStr = intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Remix.money_rupee_circle_line,
              size: 20,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commission',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upcoming Commission: ₹$amountStr',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF16A34A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
