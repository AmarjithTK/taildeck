import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Rounded dark text field used by the edit screen.
class DarkTextField extends StatelessWidget {
  const DarkTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.mono = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool mono;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 16,
      color: AppColors.textPrimary,
      fontFamily: mono ? AppText.mono.fontFamily : null,
      fontFamilyFallback: mono ? AppText.mono.fontFamilyFallback : null,
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      maxLength: maxLength,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: base,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: base.copyWith(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary),
        errorBorder: _border(AppColors.danger),
        border: _border(AppColors.border),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

/// Small label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Validation / hint line under a field.
class HelperLine extends StatelessWidget {
  const HelperLine({super.key, required this.text, required this.tone});

  final String text;
  final HelperTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, glyph) = switch (tone) {
      HelperTone.neutral => (AppColors.textSecondary, null),
      HelperTone.valid => (AppColors.success, '\u2713'),
      HelperTone.invalid => (AppColors.danger, '\u26A0'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            Text(
              glyph,
              style: TextStyle(fontSize: 12, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

enum HelperTone { neutral, valid, invalid }

/// Device-style toggle row: label on the left, switch on the right.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (helper != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      helper!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceHigh,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase group heading.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Rounded panel used to group settings rows.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: child,
  );
}
