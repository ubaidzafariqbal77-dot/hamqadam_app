import 'package:flutter/material.dart';

import '../constants/reg_icons.dart';
import 'reg_icon_badge.dart';

/// A picker-sheet row's leading icon (a [RegIcons] key) as a soft badge that
/// lifts to the brand gradient when the row is selected.
class RowGlyph extends StatelessWidget {
  const RowGlyph({super.key, required this.asset, required this.selected});

  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return RegIconBadge(
      icon: RegIcons.iconFor(asset),
      size: 38,
      soft: true,
      selected: selected,
    );
  }
}
