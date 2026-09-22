import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A picker-sheet row's leading artwork: the raw asset shown at full colour
/// inside a soft pink disc. Kept out of [IconTheme]'s data flow so image-based
/// [ListTile.leading] slots never get recoloured.
class RowGlyph extends StatelessWidget {
  const RowGlyph({super.key, required this.asset, required this.selected});

  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.10),
      ),
      padding: const EdgeInsets.all(5),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
