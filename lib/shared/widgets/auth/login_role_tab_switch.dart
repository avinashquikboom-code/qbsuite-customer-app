import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/views/auth/login_view.dart';

class LoginRoleTabSwitch extends StatelessWidget {
  final MobileUserRole currentRole;
  final ValueChanged<MobileUserRole> onRoleChanged;

  const LoginRoleTabSwitch({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildRoleCard(
          role: MobileUserRole.customer,
          title: 'Customer',
          icon: Remix.user_3_fill,
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required MobileUserRole role,
    required String title,
    required IconData icon,
  }) {
    final isSelected = currentRole == role;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onRoleChanged(role),
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.subtleGreenBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.primaryDark
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryDark
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
