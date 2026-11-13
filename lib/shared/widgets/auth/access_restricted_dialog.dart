import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/crm_access.dart';

/// Clean, responsive error component for CRM login authorization restrictions.
///
/// Clearly indicates that CRM access is limited to BPO and Sales employees,
/// displays the authorization error returned by the backend, and provides a
/// "Try Another Account" button to reset the login form.
class AccessRestrictedCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onTryAnotherAccount;
  final VoidCallback? onDismiss;
  final bool isModal;

  const AccessRestrictedCard({
    super.key,
    this.title = kCrmAccessRestrictedTitle,
    required this.message,
    required this.onTryAnotherAccount,
    this.onDismiss,
    this.isModal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: isModal ? Colors.white : const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFECACA), // Red-200
          width: 1.2,
        ),
        boxShadow: isModal
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + (Optional Dismiss)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), // Red-50
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFEE2E2), // Red-100
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Remix.shield_keyhole_line,
                    size: 22,
                    color: Color(0xFFDC2626), // Red-600
                  ),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.team_line,
                            size: 11,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'BPO & Sales Workforce Only',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(
                    Remix.close_line,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Dismiss',
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Message Body with clean paragraph styling
          Text(
            message,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF334155),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Primary Action: "Try Another Account"
          SizedBox(
            width: double.infinity,
            height: isCompact ? 44 : 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D36A), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onTryAnotherAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Remix.user_shared_line,
                      size: 17,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try Another Account',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Subtext hint
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Remix.customer_service_2_line,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Contact your administrator if you believe this is a mistake.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to display the Access Restricted error as a responsive modal sheet or dialog.
Future<void> showAccessRestrictedDialog(
  BuildContext context, {
  String title = kCrmAccessRestrictedTitle,
  required String message,
  required VoidCallback onTryAnotherAccount,
}) async {
  final width = MediaQuery.sizeOf(context).width;

  if (width < 600) {
    // Mobile modal bottom sheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          18 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AccessRestrictedCard(
                title: title,
                message: message,
                isModal: true,
                onDismiss: () => Navigator.of(ctx).pop(),
                onTryAnotherAccount: () {
                  Navigator.of(ctx).pop();
                  onTryAnotherAccount();
                },
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    // Tablet / Desktop centered dialog
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: AccessRestrictedCard(
                title: title,
                message: message,
                isModal: true,
                onDismiss: () => Navigator.of(ctx).pop(),
                onTryAnotherAccount: () {
                  Navigator.of(ctx).pop();
                  onTryAnotherAccount();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
