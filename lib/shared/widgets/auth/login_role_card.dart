import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

class LoginRoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const LoginRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: themeColor.withValues(alpha: 0.12),
        highlightColor: themeColor.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColor.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? themeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? themeColor.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.025),
                blurRadius: isSelected ? 12 : 6,
                offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Box
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            themeColor,
                            themeColor.withValues(alpha: 0.82),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.32),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : themeColor,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? themeColor
                            : const Color(0xFF0F172A),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: isSelected
                            ? const Color(0xFF475569)
                            : const Color(0xFF64748B),
                        height: 1.2,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Radio / Checkmark Badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isSelected
                    ? Icon(
                        Remix.radio_button_fill,
                        key: const ValueKey('radio_selected'),
                        color: themeColor,
                        size: 20,
                      )
                    : const Icon(
                        Remix.checkbox_blank_circle_line,
                        key: ValueKey('radio_unselected'),
                        color: Color(0xFFCBD5E1),
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
