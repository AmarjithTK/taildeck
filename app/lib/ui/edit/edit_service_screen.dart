import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/url_utils.dart';
import '../../data/models/icon_ref.dart';
import '../../data/models/service_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../common/dark_field.dart';
import '../common/icon_tile.dart';
import '../home/service_actions.dart';
import 'widgets/icon_picker.dart';
import 'widgets/test_connection_tile.dart';

/// Screen 3 — `docs/UI_SPEC.md` §4. Doubles as Add Service when [service] is
/// null.
class EditServiceScreen extends ConsumerStatefulWidget {
  const EditServiceScreen({super.key, this.service});

  final ServiceItem? service;

  @override
  ConsumerState<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends ConsumerState<EditServiceScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late IconRef _icon;
  late bool _pinned;
  late bool _probeEnabled;
  late bool _desktopMode;
  late AppOrientation _orientation;

  Timer? _validateTimer;
  UrlParseResult _urlResult = const UrlParseFailure(kUrlEmptyMessage);

  bool get _isEditing => widget.service != null;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _urlResult is UrlParseOk;

  @override
  void initState() {
    super.initState();
    final service = widget.service;

    _nameController = TextEditingController(text: service?.name ?? '');
    // Show the short form: the user typed `100.114.10.5:3000`, and seeing that
    // again is friendlier than `http://100.114.10.5:3000`.
    _urlController = TextEditingController(
      text: service == null || service.url.isEmpty
          ? ''
          : displayHostOf(service.url),
    );
    _icon =
        service?.icon ??
        const IconRef(
          kind: IconKind.material,
          value: kDefaultIconName,
          accent: 0xFF22C55E,
        );
    _pinned = service?.pinned ?? false;
    _probeEnabled = service?.probeEnabled ?? true;
    _desktopMode =
        service?.desktopMode ?? ref.read(settingsProvider).desktopModeDefault;
    _orientation = service?.orientation ?? AppOrientation.system;

    _urlResult = parseServiceUrl(_urlController.text);
  }

  @override
  void dispose() {
    _validateTimer?.cancel();
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final original = widget.service;
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (original == null) return name.isNotEmpty || url.isNotEmpty;
    return name != original.name ||
        url != displayHostOf(original.url) ||
        _pinned != original.pinned ||
        _probeEnabled != original.probeEnabled ||
        _desktopMode != original.desktopMode ||
        _orientation != original.orientation ||
        _icon != original.icon;
  }

  /// A monogram follows the name, so it is derived at save time rather than
  /// frozen when the user picked "Aa".
  IconRef get _effectiveIcon {
    if (_icon.kind != IconKind.monogram) return _icon;
    final name = _nameController.text.trim();
    return _icon.copyWith(
      value: name.isEmpty
          ? '?'
          : String.fromCharCode(name.runes.first).toUpperCase(),
    );
  }

  void _onUrlChanged(String value) {
    _validateTimer?.cancel();
    _validateTimer = Timer(K.validateDebounce, () {
      if (!mounted) return;
      setState(() => _urlResult = parseServiceUrl(value));
    });
  }

  void _save() {
    final result = _urlResult;
    if (result is! UrlParseOk) return;

    final name = _nameController.text.trim();
    final notifier = ref.read(servicesProvider.notifier);
    final existing = widget.service;

    final ServiceItem? saved;
    if (existing == null) {
      saved = notifier.add(
        name: name,
        url: result.normalized,
        icon: _effectiveIcon,
        pinned: _pinned,
        probeEnabled: _probeEnabled,
        desktopMode: _desktopMode,
        orientation: _orientation,
      );
    } else {
      saved = existing.copyWith(
        name: name,
        url: result.normalized,
        icon: _effectiveIcon,
        pinned: _pinned,
        probeEnabled: _probeEnabled,
        desktopMode: _desktopMode,
        orientation: _orientation,
      );
      notifier.update(saved);
    }

    if (saved != null) {
      unawaited(ref.read(probeProvider.notifier).probeOne(saved));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final service = widget.service;
    if (service == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Remove ${service.name}?',
      body: 'This only removes the card. The service itself is untouched.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    ref.read(servicesProvider.notifier).remove(service.id);
    ref.read(probeProvider.notifier).clearFor(service.id);
    Navigator.of(context).pop();
  }

  Future<void> _handleBack() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDialog(
      context,
      title: 'Discard changes?',
      body: 'Your edits to this service will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(
                title: _isEditing ? 'Edit Service' : 'Add Service',
                onBack: () => unawaited(_handleBack()),
                onDelete: _isEditing ? () => unawaited(_delete()) : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: <Widget>[
                    Center(
                      child: Column(
                        children: <Widget>[
                          IconTile(icon: _effectiveIcon, size: 84, radius: 22),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showIconPicker(
                                context,
                                _icon,
                              );
                              if (picked != null && mounted) {
                                setState(() => _icon = picked);
                              }
                            },
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 18),
                            label: const Text('Change Icon'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: AppColors.surfaceHigh,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const FieldLabel('Name'),
                    DarkTextField(
                      controller: _nameController,
                      hintText: 'Omaipai',
                      autofocus: !_isEditing,
                      maxLength: 32,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const FieldLabel('URL'),
                    DarkTextField(
                      controller: _urlController,
                      hintText: '100.114.10.5:3000',
                      mono: true,
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (value) {
                        _onUrlChanged(value);
                        setState(() {});
                      },
                    ),
                    _UrlHelper(result: _urlResult),
                    const SizedBox(height: 20),
                    SurfacePanel(
                      child: Column(
                        children: <Widget>[
                          ToggleRow(
                            label: 'Pin to top of grid',
                            value: _pinned,
                            onChanged: (value) =>
                                setState(() => _pinned = value),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          ToggleRow(
                            label: 'Check connection',
                            value: _probeEnabled,
                            onChanged: (value) =>
                                setState(() => _probeEnabled = value),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          ToggleRow(
                            label: 'Desktop mode',
                            helper: 'Ask the site for its desktop layout',
                            value: _desktopMode,
                            onChanged: (value) =>
                                setState(() => _desktopMode = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const FieldLabel('Orientation'),
                    SurfacePanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Applies to this service only.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<AppOrientation>(
                            segments: const <ButtonSegment<AppOrientation>>[
                              ButtonSegment<AppOrientation>(
                                value: AppOrientation.system,
                                label: Text('System'),
                                icon: Icon(
                                  Icons.screen_rotation_outlined,
                                  size: 18,
                                ),
                              ),
                              ButtonSegment<AppOrientation>(
                                value: AppOrientation.portrait,
                                label: Text('Portrait'),
                                icon: Icon(
                                  Icons.stay_current_portrait_outlined,
                                  size: 18,
                                ),
                              ),
                              ButtonSegment<AppOrientation>(
                                value: AppOrientation.landscape,
                                label: Text('Landscape'),
                                icon: Icon(
                                  Icons.stay_current_landscape_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                            selected: <AppOrientation>{_orientation},
                            onSelectionChanged:
                                (selection) => setState(
                                  () => _orientation = selection.first,
                                ),
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              selectedForegroundColor: AppColors.textPrimary,
                              selectedBackgroundColor: AppColors.surfaceHigh,
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const FieldLabel('Test Connection'),
                    TestConnectionTile(url: _urlController.text),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary
                              .withValues(alpha: 0.3),
                          disabledForegroundColor: Colors.white54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the *normalised* result before saving — the key affordance of §7.
class _UrlHelper extends StatelessWidget {
  const _UrlHelper({required this.result});

  final UrlParseResult result;

  @override
  Widget build(BuildContext context) => switch (result) {
    UrlParseOk(:final normalized) => HelperLine(
      text: 'Will open $normalized',
      tone: HelperTone.valid,
    ),
    UrlParseFailure(:final message) => HelperLine(
      text: message,
      tone: message == kUrlEmptyMessage
          ? HelperTone.neutral
          : HelperTone.invalid,
    ),
  };
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    this.onDelete,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (onDelete != null)
          SizedBox(
            width: 56,
            child: IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              icon: const Icon(
                Icons.delete_outline,
                size: 22,
                color: AppColors.danger,
              ),
            ),
          )
        else
          const SizedBox(width: 56),
      ],
    ),
  );
}
