import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'common_button.dart';

/// Reusable theme-aware confirmation dialog.
class CommonConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final IconData icon;
  final Color iconColor;
  final bool isDestructive;

  const CommonConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.icon = Remix.question_line,
    this.iconColor = AppColors.primary,
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    IconData icon = Remix.question_line,
    Color iconColor = AppColors.primary,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () {
          Navigator.pop(ctx, true);
          onConfirm();
        },
        onCancel: () {
          Navigator.pop(ctx, false);
          onCancel?.call();
        },
        icon: icon,
        iconColor: isDestructive ? AppColors.error : iconColor,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? AppColors.error : iconColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.pop(context, false),
          child: Text(
            cancelLabel,
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ),
        CommonButton(
          label: confirmLabel,
          variant: isDestructive
              ? CommonButtonVariant.danger
              : CommonButtonVariant.primary,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
