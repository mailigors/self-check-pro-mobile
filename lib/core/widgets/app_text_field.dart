import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'app_icon.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.onTap,
    this.suffix,
    this.prefix,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? suffix;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null && errorText!.isNotEmpty;
    final borderColor = isError ? AppColors.error : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 18 / 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          onTap: onTap,
          style: GoogleFonts.poppins(
            fontSize: 16,
            height: 20 / 16,
            color: AppColors.text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              fontSize: 16,
              height: 20 / 16,
              color: AppColors.placeholder,
            ),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: prefix,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isError ? AppColors.error : AppColors.brand,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
        if (isError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const AppIcon(AppIcon.warning, size: 16, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
