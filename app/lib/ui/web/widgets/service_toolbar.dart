import 'package:flutter/material.dart';

import '../../../data/models/service_item.dart';
import '../../../theme/app_theme.dart';
import 'web_progress_line.dart';

/// Actions in the toolbar's overflow menu.
enum ServiceToolbarAction {
  openExternal,
  copyAddress,
  editService,
  unloadPage,
  orientationSystem,
  orientationPortrait,
  orientationLandscape,
}

/// The service view's chrome: back, forward, address, reload, close, overflow.
///
/// The address field lives *in* this row rather than on a row of its own: an
/// earlier layout stacked a title row (name + host), a tab row and a separate
/// address row, which ate ~140dp of vertical space and printed the host three
/// times. The tab's URL now appears exactly once, editable, where a browser
/// puts it.
///
/// Two older corrections are still baked in:
///
/// 1. The first version had no chrome at all ("just the WebView"), which left no
///    way to reload a wedged page.
/// 2. The second version had a single left button that *morphed* between a back
///    arrow and a close cross depending on history. That was too clever: as soon
///    as you navigated anywhere the arrow took over, and there was no longer any
///    way to leave the service except pressing back once per page. Back and
///    close are now two separate, permanently visible buttons, each disabled
///    when it has nothing to do.
///
/// Everything that changes during navigation is read from [ValueListenable]s
/// *inside* this widget rather than passed in as plain values, so a history or
/// loading change rebuilds the toolbar alone and never touches the
/// `WebViewWidget` subtree.
class ServiceToolbar extends StatelessWidget {
  const ServiceToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.loading,
    required this.progress,
    required this.urlController,
    required this.urlFocus,
    required this.onUrlSubmit,
    required this.onBack,
    required this.onForward,
    required this.onFullscreen,
    required this.onReload,
    required this.onClose,
    required this.onAction,
    this.orientation,
  });

  /// Height of the control row, excluding the status-bar inset.
  static const double controlHeight = 52;

  /// Width of one control. Five of them leave room for the address field on a
  /// 360dp phone.
  static const double buttonWidth = 44;

  final ValueNotifier<bool> canGoBack;
  final ValueNotifier<bool> canGoForward;
  final ValueNotifier<bool> loading;
  final ValueNotifier<double> progress;

  /// The active tab's address, owned by the service view: it follows
  /// navigation while the user is not editing, and navigates on submit.
  final TextEditingController urlController;
  final FocusNode urlFocus;
  final VoidCallback onUrlSubmit;

  /// The service's orientation lock, rendered as a checkmark in the overflow
  /// menu. Null hides the checkmarks (e.g. in tests that don't care).
  final AppOrientation? orientation;

  /// One step back in page history.
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// Hides every bar (this toolbar, the tab strip, the system bars) so the
  /// page gets the whole screen. A floating button leaves fullscreen.
  final VoidCallback onFullscreen;

  final VoidCallback onReload;

  /// Leave the service and return to the grid. The session stays warm.
  final VoidCallback onClose;

  final ValueChanged<ServiceToolbarAction> onAction;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: controlHeight,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[
                    canGoBack,
                    canGoForward,
                    loading,
                  ]),
                  builder: (context, _) => Row(
                    children: <Widget>[
                      _ToolbarButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onTap: canGoBack.value ? onBack : null,
                      ),
                      _ToolbarButton(
                        icon: Icons.arrow_forward,
                        tooltip: 'Forward',
                        onTap: canGoForward.value ? onForward : null,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 7,
                          ),
                          child: _AddressField(
                            controller: urlController,
                            focus: urlFocus,
                            onSubmit: onUrlSubmit,
                          ),
                        ),
                      ),
                      _ToolbarButton(
                        icon: Icons.fullscreen,
                        tooltip: 'Fullscreen',
                        onTap: onFullscreen,
                      ),
                      _ToolbarButton(
                        icon: Icons.refresh,
                        tooltip: 'Reload',
                        onTap: onReload,
                      ),
                      _ToolbarButton(
                        icon: Icons.close,
                        tooltip: 'Back to services',
                        onTap: onClose,
                      ),
                      _OverflowMenu(onAction: onAction, orientation: orientation),
                    ],
                  ),
                ),
              ),
            ),
            // Pinned to the bottom edge of the toolbar, the way a browser puts
            // it, rather than floating over the page.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WebProgressLine(progress: progress, loading: loading),
            ),
          ],
        ),
      ),
    );
  }
}

/// The active tab's address, editable in place. One field, one URL, no
/// repeated host line above or below it.
class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    height: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    alignment: Alignment.center,
    child: TextField(
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.url,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => onSubmit(),
      style: AppText.mono.copyWith(
        fontSize: 12,
        color: AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        hintText: 'Address',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Null renders the button disabled, which is how back and forward read when
  /// there is nowhere to go.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ServiceToolbar.buttonWidth,
    height: double.infinity,
    child: IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null
            ? AppColors.textDisabled
            : AppColors.textPrimary,
      ),
    ),
  );
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onAction, required this.orientation});

  final ValueChanged<ServiceToolbarAction> onAction;

  /// The service's current orientation lock, shown as a checkmark.
  final AppOrientation? orientation;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ServiceToolbar.buttonWidth,
    height: double.infinity,
    child: PopupMenuButton<ServiceToolbarAction>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      color: AppColors.surfaceHigh,
      position: PopupMenuPosition.under,
      icon: const Icon(
        Icons.more_vert,
        size: 22,
        color: AppColors.textPrimary,
      ),
      onSelected: onAction,
      itemBuilder: (context) => <PopupMenuEntry<ServiceToolbarAction>>[
        _menuEntry(
          ServiceToolbarAction.openExternal,
          Icons.open_in_new,
          'Open in browser',
        ),
        _menuEntry(
          ServiceToolbarAction.copyAddress,
          Icons.link,
          'Copy address',
        ),
        _menuEntry(
          ServiceToolbarAction.editService,
          Icons.tune,
          'Service settings',
        ),
        const PopupMenuDivider(),
        _menuEntry(
          ServiceToolbarAction.orientationSystem,
          Icons.screen_rotation_outlined,
          'Rotation: system default',
          checked: orientation == null,
        ),
        _menuEntry(
          ServiceToolbarAction.orientationPortrait,
          Icons.stay_current_portrait_outlined,
          'Lock portrait',
          checked: orientation == AppOrientation.portrait,
        ),
        _menuEntry(
          ServiceToolbarAction.orientationLandscape,
          Icons.stay_current_landscape_outlined,
          'Lock landscape',
          checked: orientation == AppOrientation.landscape,
        ),
        const PopupMenuDivider(),
        _menuEntry(
          ServiceToolbarAction.unloadPage,
          Icons.layers_clear_outlined,
          'Unload page',
        ),
      ],
    ),
  );
}

PopupMenuItem<ServiceToolbarAction> _menuEntry(
  ServiceToolbarAction value,
  IconData icon,
  String label, {
  bool checked = false,
}) => PopupMenuItem<ServiceToolbarAction>(
  value: value,
  child: Row(
    children: <Widget>[
      Icon(icon, size: 20, color: AppColors.textSecondary),
      const SizedBox(width: 14),
      // Flexible so a long label (or a large text scale) ellipsizes rather than
      // overflowing the menu's fixed width.
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
      ),
      if (checked)
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.check, size: 18, color: AppColors.primary),
        ),
    ],
  ),
);
