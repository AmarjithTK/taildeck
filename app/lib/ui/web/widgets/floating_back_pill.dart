import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// The only chrome in the service view — `docs/UI_SPEC.md` §3.2.
///
/// Bottom-right on purpose: it is the natural thumb position one-handed, and it
/// stays clear of the left-edge system back gesture so the two never compete.
/// Returns a [Positioned], so it must be a direct `Stack` child.
class FloatingBackPill extends StatelessWidget {
  const FloatingBackPill({
    super.key,
    required this.idle,
    required this.onTap,
    required this.onLongPress,
  });

  /// Drives the auto-fade. Owned by the parent so a touch anywhere in the view
  /// can restore it.
  final bool idle;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      right: 16,
      bottom: 16 + bottom,
      child: AnimatedOpacity(
        opacity: idle ? 0.4 : 1,
        duration: const Duration(milliseconds: 400),
        child: Semantics(
          button: true,
          label: 'Back',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: AppColors.surfaceHigh.withValues(alpha: 0.72),
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
