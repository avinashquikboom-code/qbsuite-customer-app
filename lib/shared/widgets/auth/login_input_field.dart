import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onTogglePassword;
  final TextInputType? keyboardType;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const LoginInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onTogglePassword,
    this.keyboardType,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF101828),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: const Color(0xFF98A2B3),
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF23C45E), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF23C45E),
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF23C45E), width: 1.5),
        ),
      ),
    );
  }
}
