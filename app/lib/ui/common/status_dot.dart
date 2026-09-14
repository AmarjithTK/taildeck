import 'package:flutter/material.dart';

import '../../data/models/probe_status.dart';
import '../../theme/app_theme.dart';

/// Maps a probe result onto the dot's appearance, honouring the per-service
/// "Check connection" opt-out.
ProbeDotState dotStateFor(ProbeStatus? status, {required bool probeEnabled}) {
  if (!probeEnabled) return ProbeDotState.disabled;
  return switch (status?.state) {
    ProbeState.online => ProbeDotState.online,
    ProbeState.offline => ProbeDotState.offline,
    ProbeState.checking => ProbeDotState.checking,
    ProbeState.unknown || null => ProbeDotState.unknown,
  };
}

/// 8dp status indicator. Colour is never the only signal — it is always paired
/// with text elsewhere (banner copy, test tile copy), so the UI does not rely
/// on red/green discrimination alone.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.state, this.size = 8});

  final ProbeDotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (state == ProbeDotState.checking) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forState(state),
        shape: BoxShape.circle,
      ),
    );
  }
}
