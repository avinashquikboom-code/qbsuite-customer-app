import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// A 6-box responsive OTP input widget supporting auto-advance, backspace,
/// paste full 6-digit code, and clear active/error styling.
class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool autoFocus;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.autoFocus = true,
  });

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

class OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    if (widget.autoFocus && _focusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNodes[0].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get otpCode => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty && mounted) {
      _focusNodes[0].requestFocus();
    }
    setState(() {});
  }

  void _handleChanged(int index, String value) {
    if (value.length > 1) {
      // Possible paste event
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= widget.length) {
        for (int i = 0; i < widget.length; i++) {
          _controllers[i].text = digits[i];
        }
        _focusNodes[widget.length - 1].requestFocus();
        _notifyUpdate();
        return;
      } else {
        // Take the last entered character
        _controllers[index].text = value.substring(value.length - 1);
      }
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    _notifyUpdate();
  }

  void _notifyUpdate() {
    final currentCode = otpCode;
    widget.onChanged?.call(currentCode);
    if (currentCode.length == widget.length) {
      widget.onCompleted(currentCode);
    }
    setState(() {});
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _notifyUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Total slots = length (6), total gaps = length - 1 (5)
        const minGap = 6.0;
        const maxBoxWidth = 48.0;
        final availableForBoxes = totalWidth - ((widget.length - 1) * minGap);
        final computedBoxWidth = (availableForBoxes / widget.length).clamp(38.0, maxBoxWidth);
        final boxHeight = computedBoxWidth * 1.25;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            final isFocused = _focusNodes[index].hasFocus;
            final hasValue = _controllers[index].text.isNotEmpty;

            Color borderColor = const Color(0xFFE2E8F0);
            Color bgColor = Colors.white;

            if (widget.hasError) {
              borderColor = AppColors.error;
              bgColor = const Color(0xFFFEF2F2);
            } else if (isFocused) {
              borderColor = AppColors.primary;
              bgColor = const Color(0xFFF0FDF4);
            } else if (hasValue) {
              borderColor = const Color(0xFFCBD5E1);
            }

            return SizedBox(
              width: computedBoxWidth,
              height: boxHeight,
              child: KeyboardListener(
                focusNode: FocusNode(), // Dummy node for backspace listener
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    _handleBackspace(index);
                  }
                },
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: bgColor,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: widget.hasError ? AppColors.error : AppColors.primary,
                        width: 2.0,
                      ),
                    ),
                  ),
                  onChanged: (val) => _handleChanged(index, val),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
