import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/probe_status.dart';
import '../../data/models/service_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../edit/edit_service_screen.dart';

/// Opens a service, or sends an unconfigured card straight to the editor.
void openService(BuildContext context, WidgetRef ref, ServiceItem service) {
  if (!service.isConfigured) {
    unawaited(editService(context, ref, service));
    return;
  }
  ref.read(sessionRegistryProvider).acquire(service);
}

/// [service] null means "add a new one".
Future<void> editService(
  BuildContext context,
  WidgetRef ref,
  ServiceItem? service,
) async {
  if (service == null && ref.read(servicesProvider.notifier).isFull) {
    showToast(
      context,
      'All ${K.maxServices} slots are in use. Remove one first.',
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EditServiceScreen(service: service),
    ),
  );
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: Text(
        body,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The `⋮` menu — ARCHITECTURE.md, card overflow sheet.
Future<void> showServiceOverflowSheet(
  BuildContext context,
  WidgetRef ref,
  ServiceItem service,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final registry = ref.read(sessionRegistryProvider);

  final action = await showModalBottomSheet<_CardAction>(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _Grabber(),
          _SheetTile(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.edit),
          ),
          _SheetTile(
            icon: Icons.network_check,
            label: 'Test connection',
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.test),
          ),
          _SheetTile(
            icon: Icons.open_in_new,
            label: 'Open in browser',
            enabled: service.isConfigured,
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.browser),
          ),
          _SheetTile(
            icon: Icons.copy_all_outlined,
            label: 'Duplicate',
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.duplicate),
          ),
          _SheetTile(
            icon: Icons.layers_clear_outlined,
            label: 'Close session',
            subtitle: registry.isLive(service.id) ? null : 'Not open',
            enabled: registry.isLive(service.id),
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.close),
          ),
          _SheetTile(
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: true,
            onTap: () => Navigator.of(sheetContext).pop(_CardAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null) return;

  switch (action) {
    case _CardAction.edit:
      if (context.mounted) unawaited(editService(context, ref, service));

    case _CardAction.test:
      messenger.showSnackBar(
        const SnackBar(content: Text('Testing\u2026')),
      );
      await ref.read(probeProvider.notifier).probeOne(service);
      final status = ref.read(probeProvider)[service.id];
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(_probeSummary(status))));

    case _CardAction.browser:
      final opened = await ref
          .read(platformBridgeProvider)
          .openExternal(service.url);
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No app can open that address')),
        );
      }

    case _CardAction.duplicate:
      final copy = ref.read(servicesProvider.notifier).duplicate(service.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            copy == null ? 'No free slots' : 'Duplicated ${service.name}',
          ),
        ),
      );

    case _CardAction.close:
      registry.close(service.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Session closed. It will reload next time.'),
        ),
      );

    case _CardAction.delete:
      if (!context.mounted) return;
      final confirmed = await confirmDialog(
        context,
        title: 'Remove ${service.name}?',
        body:
            'This only removes the card. The service itself is untouched.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!confirmed) return;
      ref.read(servicesProvider.notifier).remove(service.id);
      ref.read(probeProvider.notifier).clearFor(service.id);
  }
}

String _probeSummary(ProbeStatus? status) {
  if (status == null || status.state == ProbeState.unknown) {
    return 'Not tested';
  }
  return switch (status.state) {
    ProbeState.checking => 'Testing\u2026',
    ProbeState.online when status.needsAuth =>
      'Reachable \u00B7 HTTP ${status.httpStatus} (wants credentials)',
    ProbeState.online => 'Reachable \u00B7 ${status.latencyMs} ms',
    ProbeState.offline => 'Unreachable \u00B7 ${status.error ?? 'unknown'}',
    ProbeState.unknown => 'Not tested',
  };
}

enum _CardAction { edit, test, browser, duplicate, close, delete }

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 6),
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool enabled;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.textDisabled
        : destructive
        ? AppColors.danger
        : AppColors.textPrimary;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: TextStyle(fontSize: 15, color: color)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
