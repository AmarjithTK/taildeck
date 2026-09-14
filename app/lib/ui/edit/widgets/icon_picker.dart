import 'package:flutter/material.dart';

import '../../../data/models/icon_ref.dart';
import '../../../theme/app_theme.dart';
import '../../common/dashed_border.dart';
import '../../common/icon_tile.dart';

/// Icon picker sheet — `docs/UI_SPEC.md` §4.1.
///
/// Everything is local: a curated glyph set, a monogram, and twelve accents.
/// No favicon is ever fetched, because a favicon service cannot resolve a
/// tailnet address anyway.
Future<IconRef?> showIconPicker(BuildContext context, IconRef current) =>
    showModalBottomSheet<IconRef>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _IconPickerSheet(initial: current),
    );

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({required this.initial});

  final IconRef initial;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  late IconRef _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final names = kMaterialIcons.keys.toList(growable: false);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            IconTile(icon: _draft, size: 72, radius: 20),
            const SizedBox(height: 18),
            const _Label('Colour'),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: kAccentSwatches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final accent = kAccentSwatches[index];
                  final selected = _draft.accent == accent;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _draft = _draft.copyWith(accent: accent);
                    }),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(accent),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const _Label('Icon'),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                itemCount: names.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _PickTile(
                      selected: _draft.kind == IconKind.monogram,
                      onTap: () => setState(() {
                        _draft = IconRef(
                          kind: IconKind.monogram,
                          value: _draft.value.isEmpty ||
                                  _draft.kind != IconKind.monogram
                              ? 'A'
                              : _draft.value,
                          accent: _draft.accent,
                        );
                      }),
                      child: const Text(
                        'Aa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }
                  final name = names[index - 1];
                  return _PickTile(
                    selected:
                        _draft.kind == IconKind.material &&
                        _draft.value == name,
                    onTap: () => setState(() {
                      _draft = IconRef(
                        kind: IconKind.material,
                        value: name,
                        accent: _draft.accent,
                      );
                    }),
                    child: Icon(
                      kMaterialIcons[name],
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DashedRRectBorder(
      color: selected ? AppColors.primary : Colors.transparent,
      radius: 12,
      strokeWidth: 1.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    ),
  );
}
