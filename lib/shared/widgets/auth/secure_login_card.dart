import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

class SecureLoginCard extends StatelessWidget {
  const SecureLoginCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Remix.shield_check_fill,
            color: Color(0xFF23C45E),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Login',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF166534),
                  ),
                ),
                Text(
                  'Your data is protected with advanced security',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Remix.shield_check_line,
            color: Color(0xFF23C45E),
            size: 26,
          ),
        ],
      ),
    );
  }
}
