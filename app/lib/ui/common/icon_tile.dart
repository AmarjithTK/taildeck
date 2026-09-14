import 'package:flutter/material.dart';

import '../../data/models/icon_ref.dart';

/// A service's glyph on a tinted rounded tile. Used at three sizes: the grid
/// card, the edit screen and the error view.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = 14,
    this.opacity = 1,
  });

  final IconRef icon;
  final double size;
  final double radius;

  /// Drops the whole tile towards the background — used for offline services.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final accent = Color(icon.accent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14 * opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: _glyph(accent.withValues(alpha: opacity)),
    );
  }

  Widget _glyph(Color color) {
    switch (icon.kind) {
      case IconKind.material:
        final data = icon.iconData;
        if (data != null) {
          return Icon(data, size: size * 0.55, color: color);
        }
        // The stored glyph name is not in the catalogue (an older or newer
        // build wrote it). Fall back to the monogram rather than a blank tile.
        return _monogram(color);
      case IconKind.monogram:
        return _monogram(color);
      case IconKind.emoji:
        return Text(
          icon.value,
          style: TextStyle(fontSize: size * 0.48, color: color),
        );
    }
  }

  Widget _monogram(Color color) {
    final letter = icon.value.isEmpty ? '?' : icon.value;
    return Text(
      letter,
      style: TextStyle(
        fontSize: size * 0.44,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
