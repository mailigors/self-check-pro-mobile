import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.inputFormatters,
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
    this.fillColor = AppColors.surface,
  });

  final String? label;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
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
  final Color fillColor;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = isError ? AppColors.error : AppColors.border;
    final suffix =
        widget.suffix ??
        (widget.obscureText
            ? IconButton(
                tooltip: _obscured ? 'Показать пароль' : 'Скрыть пароль',
                onPressed: () => setState(() => _obscured = !_obscured),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                splashRadius: 22,
                icon: AppIcon(
                  _obscured ? AppIcon.eye : AppIcon.eyeOff,
                  size: 24,
                  color: AppColors.placeholder,
                ),
              )
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyH5(color: AppColors.text)
                .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          inputFormatters: widget.inputFormatters,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          cursorColor: AppColors.brand,
          style: AppText.bodyH3(
            color: isError ? AppColors.error : AppColors.text,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppText.bodyH3(
              color: isError ? AppColors.error : AppColors.placeholder,
            ),
            filled: true,
            fillColor: widget.fillColor,
            prefixIcon: widget.prefix,
            suffixIcon: suffix,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 24,
              maxHeight: 56,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 24,
              maxHeight: 56,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            constraints: const BoxConstraints(minHeight: 56),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.maxLines == 1 ? 28 : 20,
              ),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.maxLines == 1 ? 28 : 20,
              ),
              borderSide: BorderSide(
                color: isError ? AppColors.error : AppColors.brand,
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.maxLines == 1 ? 28 : 20,
              ),
              borderSide: BorderSide(
                color: isError ? AppColors.error : AppColors.borderSubtle,
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.maxLines == 1 ? 28 : 20,
              ),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.maxLines == 1 ? 28 : 20,
              ),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
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
                  widget.errorText!,
                  style: AppText.bodyH5(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
