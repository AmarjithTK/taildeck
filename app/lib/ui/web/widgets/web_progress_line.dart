import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../theme/app_theme.dart';

/// The 2px loading indicator.
///
/// A plain widget rather than a `Positioned`, so the caller decides where it
/// sits — today that is the bottom edge of the service toolbar, the way a
/// browser puts it. It fades out completely once loading finishes, so it costs
/// no repaint while idle.
class WebProgressLine extends StatelessWidget {
  const WebProgressLine({
    super.key,
    required this.progress,
    required this.loading,
  });

  final ValueNotifier<double> progress;
  final ValueNotifier<bool> loading;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<bool>(
      valueListenable: loading,
      builder: (context, isLoading, _) => AnimatedOpacity(
        opacity: isLoading ? 1 : 0,
        duration: K.progressFade,
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: const SizedBox(
                height: 2,
                child: ColoredBox(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
