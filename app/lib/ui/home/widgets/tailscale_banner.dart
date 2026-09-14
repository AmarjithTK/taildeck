import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../common/status_dot.dart';

/// Connection banner — `docs/UI_SPEC.md` §2.2.
///
/// Tapping it re-runs every probe and re-reads the VPN state, which is the
/// manual refresh affordance. (The spec also listed pull-to-refresh, but the
/// grid is deliberately sized to fill the screen exactly and never scroll, so
/// there is no overscroll gesture to hang a `RefreshIndicator` on.)
class TailscaleBanner extends ConsumerWidget {
  const TailscaleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bannerProvider);

    final (ProbeDotState dot, String title, String? subtitle, Color color) =
        switch (state) {
          BannerState.connected => (
            ProbeDotState.online,
            'Tailscale Connected',
            null,
            AppColors.textPrimary,
          ),
          BannerState.checking => (
            ProbeDotState.checking,
            'Checking connections\u2026',
            null,
            AppColors.textSecondary,
          ),
          BannerState.vpnOff => (
            ProbeDotState.offline,
            'Tailscale appears off',
            'Turn on the VPN, then tap Retry.',
            AppColors.danger,
          ),
          BannerState.servicesDown => (
            ProbeDotState.warning,
            'VPN up, services not responding',
            'Is the service still running on your PC?',
            AppColors.warning,
          ),
          BannerState.allDisabled => (
            ProbeDotState.disabled,
            'Connection checks are off',
            null,
            AppColors.textSecondary,
          ),
        };

    final actionable =
        state == BannerState.connected ||
        state == BannerState.checking ||
        state == BannerState.allDisabled;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.invalidate(vpnStateProvider);
          unawaited(ref.read(probeProvider.notifier).probeAll());
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              StatusDot(state: dot, size: 9),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionable)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                )
              else
                const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
