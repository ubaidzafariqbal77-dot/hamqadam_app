import 'package:flutter/material.dart';

import '../constants/reg_icons.dart';
import 'reg_icon_badge.dart';

/// The icon hero at the top of a registration step. [asset] is a
/// [RegIcons] key; [icon] overrides it when a step names its own glyph.
class StepArt extends StatelessWidget {
  const StepArt({super.key, required this.asset, this.icon, this.height = 132});

  final String asset;
  final IconData? icon;

  /// Kept for API compatibility; the hero sizes itself.
  final double height;

  @override
  Widget build(BuildContext context) {
    return RegHeroIcon(icon: icon ?? RegIcons.iconFor(asset));
  }
}
