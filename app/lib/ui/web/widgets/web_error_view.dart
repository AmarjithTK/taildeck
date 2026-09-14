import 'package:flutter/material.dart';

import '../../../data/models/service_item.dart';
import '../../../theme/app_theme.dart';
import '../../common/icon_tile.dart';

/// Written for a human, not a stack trace — `docs/UI_SPEC.md` §3.3.
String describeErrorDetail(String error, ServiceItem service) {
  final origin = service.uri;
  final port = origin?.hasPort == true
      ? origin!.port
      : (origin?.scheme == 'https' ? 443 : 80);
  return switch (error) {
    'Connection refused' =>
      'The service did not accept the connection on port $port.',
    'Connection timed out' =>
      'No response in 15 seconds. The host may be asleep.',
    'No route to host' => 'Tailscale may not be connected on this device.',
    'Host not found' => 'That address did not resolve.',
    'TLS handshake failed' =>
      'The certificate was rejected. Try http:// instead of https://.',
    'Cleartext HTTP is blocked' =>
      'Android blocked the plain HTTP request to this address.',
    'Tap to configure' => 'Set an address for this service first.',
    'Page crashed' => 'The page ran out of memory. Retry reloads it.',
    _ => 'If Tailscale is off, turn it on, then tap Retry.',
  };
}

/// Shown in place of the page when the main frame fails to load.
class WebErrorView extends StatelessWidget {
  const WebErrorView({
    super.key,
    required this.service,
    required this.error,
    required this.onRetry,
    required this.onOpenExternal,
  });

  final ServiceItem service;
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    // Opaque so it fully covers whatever the WebView last painted.
    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Opacity(
                  opacity: 0.5,
                  child: IconTile(
                    icon: service.icon,
                    size: 72,
                    radius: 20,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  service.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.displayHost,
                  textAlign: TextAlign.center,
                  style: AppText.mono.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  describeErrorDetail(error, service),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onOpenExternal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Open in browser',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
