import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/service_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../common/dark_field.dart';
import '../home/service_actions.dart';

/// Screen 4 — `docs/UI_SPEC.md` §5.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 56,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: <Widget>[
                  const SectionHeader('Performance'),
                  SurfacePanel(
                    child: _NavRow(
                      label: 'Keep loaded services',
                      helper: 'More services stay instant, but use more memory.',
                      value: '${settings.sessionCapacity}',
                      onTap: () => _pickInt(
                        context,
                        title: 'Keep loaded services',
                        values: <int>[
                          for (
                            var i = K.minSessionCapacity;
                            i <= K.maxSessionCapacity;
                            i++
                          )
                            i,
                        ],
                        current: settings.sessionCapacity,
                        onPicked: (value) => notifier.update(
                          (s) => s.copyWith(sessionCapacity: value),
                        ),
                      ),
                    ),
                  ),

                  const SectionHeader('Connections'),
                  SurfacePanel(
                    child: Column(
                      children: <Widget>[
                        ToggleRow(
                          label: 'Auto-check connections',
                          value: settings.autoProbe,
                          onChanged: (value) =>
                              notifier.update((s) => s.copyWith(autoProbe: value)),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _NavRow(
                          label: 'Check interval',
                          value: '${settings.probeIntervalSec}s',
                          onTap: () => _pickInt(
                            context,
                            title: 'Check interval',
                            values: K.probeIntervalChoices,
                            current: settings.probeIntervalSec,
                            suffix: 's',
                            onPicked: (value) => notifier.update(
                              (s) => s.copyWith(probeIntervalSec: value),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        ToggleRow(
                          label: 'Only while on Home',
                          helper: 'Pauses probing while a service is open.',
                          value: settings.onlyProbeOnHome,
                          onChanged: (value) => notifier.update(
                            (s) => s.copyWith(onlyProbeOnHome: value),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader('Browsing'),
                  SurfacePanel(
                    child: Column(
                      children: <Widget>[
                        ToggleRow(
                          label: 'Show floating back button',
                          helper:
                              'A second back button at the bottom of the page, '
                              'for one-handed reach.',
                          value: settings.showFloatingBack,
                          onChanged: (value) => notifier.update(
                            (s) => s.copyWith(showFloatingBack: value),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _NavRow(
                          label: 'Links outside tailnet',
                          helper:
                              'Private services open here. Everything else goes '
                              'to your browser.',
                          value: _policyLabel(settings.externalLinkPolicy),
                          onTap: () => _pickPolicy(
                            context,
                            current: settings.externalLinkPolicy,
                            onPicked: (value) => notifier.update(
                              (s) => s.copyWith(externalLinkPolicy: value),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        ToggleRow(
                          label: 'Desktop mode by default',
                          helper: 'Applies to services you add from now on.',
                          value: settings.desktopModeDefault,
                          onChanged: (value) => notifier.update(
                            (s) => s.copyWith(desktopModeDefault: value),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader('Data'),
                  SurfacePanel(
                    child: Column(
                      children: <Widget>[
                        _NavRow(
                          label: 'Export services',
                          helper: 'Copies all cards as JSON to the clipboard.',
                          value: '${services.length}',
                          onTap: () => unawaited(_export(context, ref)),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _NavRow(
                          label: 'Import services',
                          helper: 'Reads a TailDeck export from the clipboard.',
                          value: '',
                          onTap: () => unawaited(_import(context, ref)),
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader('About'),
                  SurfacePanel(
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TailDeck 0.1.0',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'No telemetry. Your addresses never leave this '
                          'device.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => unawaited(_reset(context, ref)),
                    child: const Text(
                      'Reset all data',
                      style: TextStyle(color: AppColors.danger),
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

  static String _policyLabel(ExternalLinkPolicy policy) => switch (policy) {
    ExternalLinkPolicy.inApp => 'In-app',
    ExternalLinkPolicy.external => 'External',
    ExternalLinkPolicy.block => 'Block',
  };

  Future<void> _pickInt(
    BuildContext context, {
    required String title,
    required List<int> values,
    required int current,
    required ValueChanged<int> onPicked,
    String suffix = '',
  }) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        children: <Widget>[
          RadioGroup<int>(
            groupValue: current,
            onChanged: (next) => Navigator.of(dialogContext).pop(next),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final value in values)
                  RadioListTile<int>(
                    value: value,
                    activeColor: AppColors.primary,
                    title: Text(
                      '$value$suffix',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickPolicy(
    BuildContext context, {
    required ExternalLinkPolicy current,
    required ValueChanged<ExternalLinkPolicy> onPicked,
  }) async {
    final picked = await showDialog<ExternalLinkPolicy>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text(
          'Links outside tailnet',
          style: TextStyle(fontSize: 17),
        ),
        children: <Widget>[
          RadioGroup<ExternalLinkPolicy>(
            groupValue: current,
            onChanged: (next) => Navigator.of(dialogContext).pop(next),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final policy in ExternalLinkPolicy.values)
                  RadioListTile<ExternalLinkPolicy>(
                    value: policy,
                    activeColor: AppColors.primary,
                    title: Text(
                      _policyLabel(policy),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final items = ref.read(servicesProvider);
    final payload = jsonEncode(<String, dynamic>{
      'schema': 1,
      'items': <Map<String, dynamic>>[
        for (final item in items) item.toJson(),
      ],
    });
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    showToast(context, 'Copied ${items.length} services to the clipboard');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!context.mounted) return;
    if (text == null || text.trim().isEmpty) {
      showToast(context, 'The clipboard is empty');
      return;
    }

    List<ServiceItem> items;
    try {
      final decoded = jsonDecode(text);
      final raw = decoded is Map<String, dynamic> ? decoded['items'] : null;
      if (raw is! List) throw const FormatException('missing items');
      items = <ServiceItem>[
        for (final entry in raw)
          if (entry is Map<String, dynamic>) ServiceItem.fromJson(entry),
      ];
    } on Object {
      showToast(context, "That clipboard text isn't a TailDeck export");
      return;
    }

    if (items.isEmpty) {
      showToast(context, 'No services found in the clipboard');
      return;
    }
    if (!context.mounted) return;

    final confirmed = await confirmDialog(
      context,
      title: 'Replace all services?',
      body:
          'Your current cards will be replaced by these ${items.length}. '
          'This cannot be undone.',
      confirmLabel: 'Replace',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    ref.read(servicesProvider.notifier).replaceAll(items);
    showToast(context, 'Imported ${items.length} services');
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Reset all data?',
      body:
          'Every card and every setting is removed. Export first if you want '
          'a copy.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    ref.read(sessionRegistryProvider).closeAll();
    ref.read(servicesProvider.notifier).replaceAll(<ServiceItem>[]);
    ref.read(settingsProvider.notifier).update((_) => const AppSettings());
    if (!context.mounted) return;
    showToast(context, 'All data reset');
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.helper,
    this.value = '',
  });

  final String label;
  final String? helper;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value.isNotEmpty) ...<Widget>[
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
