import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'edit_profile_view.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionManagerProvider);
    final canViewProfile = perms.canViewSetting('PROFILE');
    final canViewNotifications = perms.canViewSetting('NOTIFICATIONS');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Account Settings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canViewProfile) ...[
              _buildSectionHeader('Profile & Security'),
              const SizedBox(height: 12),
              _buildSettingsContainer(
                children: [
                  _buildSettingsTile(
                    context,
                    title: 'Profile Information',
                    subtitle: 'Edit your name, email and avatar',
                    icon: Remix.user_3_line,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileView(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    context,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    icon: Remix.lock_2_line,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileView(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 12),
            _buildSettingsContainer(
              children: [
                if (canViewNotifications) ...[
                  _buildSettingsTile(
                    context,
                    title: 'Notifications',
                    subtitle: 'Manage app and email alerts',
                    icon: Remix.notification_3_line,
                    onTap: () {},
                  ),
                  _buildDivider(),
                ],
                _buildSettingsTile(
                  context,
                  title: 'Appearance',
                  subtitle: 'Themes and layout options',
                  icon: Remix.palette_line,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingsTile(
                  context,
                  title: 'Language',
                  subtitle: 'English (US)',
                  icon: Remix.translate_2,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('About'),
            const SizedBox(height: 12),
            _buildSettingsContainer(
              children: [
                _buildSettingsTile(
                  context,
                  title: 'Privacy Policy',
                  icon: Remix.article_line,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingsTile(
                  context,
                  title: 'Terms of Service',
                  icon: Remix.file_text_line,
                  onTap: () {},
                ),
                _buildDivider(),
                _buildSettingsTile(
                  context,
                  title: 'App Version',
                  subtitle: 'v1.0.0 (Build 12)',
                  icon: Remix.information_line,
                  hideTrailing: true,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 52,
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool hideTrailing = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: hideTrailing
          ? null
          : const Icon(
              Remix.arrow_right_s_line,
              color: AppColors.textPlaceholder,
              size: 20,
            ),
    );
  }
}
