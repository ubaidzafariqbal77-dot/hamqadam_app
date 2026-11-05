import 'package:flutter/material.dart';

import '../constants/reg_icons.dart';
import 'reg_icon_badge.dart';

/// The illustrated icon at the top of a registration step: a transparent
/// Icons8 "Fluency" image (assets/images/steps/) floating in a soft blush
/// halo. Keys without an image fall back to the gradient [RegHeroIcon].
///
/// Icons by Icons8 (https://icons8.com) — free licence requires this credit.
class StepArt extends StatelessWidget {
  const StepArt({super.key, required this.asset, this.icon, this.height = 132});

  final String asset;
  final IconData? icon;
  final double height;

  static const String _dir = 'assets/images/steps';
  static const Map<String, String> _images = <String, String>{
    RegIcons.step02BasicInfo: 'calendar',
    RegIcons.step03Faith: 'mosque',
    RegIcons.step04Location: 'marker',
    RegIcons.step05Contact: 'phone',
    RegIcons.step06Caste: 'conference-call',
    RegIcons.step08Education: 'graduation-cap',
    RegIcons.heightRuler: 'ruler',
    RegIcons.step10Career: 'briefcase',
    RegIcons.step11Security: 'lock',
    RegIcons.step12Photos: 'camera',
    RegIcons.step13About: 'edit-file',
    RegIcons.step14Verification: 'verified-account',
    RegIcons.step15Interests: 'like',
    RegIcons.step16Family: 'family',
    RegIcons.step17FamilyDetails: 'home',
    RegIcons.step18Partner: 'wedding-rings',
  };

  @override
  Widget build(BuildContext context) {
    final String? img = _images[asset];
    if (img == null) {
      return RegHeroIcon(icon: icon ?? RegIcons.iconFor(asset));
    }
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, double s, Widget? child) => Transform.scale(scale: s, child: child),
        child: Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFDEEF3)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFB25C82).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset('$_dir/$img.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
