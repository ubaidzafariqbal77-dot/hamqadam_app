import 'package:flutter/material.dart';


/// The registration flow's icon treatment: a rounded-square container on the
/// brand gradient with a soft rose glow and a white rounded glyph. Replaces
/// the old raster illustrations so every step reads in one visual language.
///
/// [soft] draws the quieter variant (blush fill, rose glyph) used for list
/// rows and unselected cards; [selected] lifts a soft badge to the gradient.
class RegIconBadge extends StatelessWidget {
  const RegIconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.soft = false,
    this.selected = false,
  });

  final IconData icon;
  final double size;
  final bool soft;
  final bool selected;

  /// Colourful gradient per subject (blue for career, green for growth,
  /// violet for faith…), so each field reads at a glance.
  static const List<Color> _rose = <Color>[Color(0xFFFF8FB1), Color(0xFFE5487A)];
  static const List<Color> _blue = <Color>[Color(0xFF7CC6FF), Color(0xFF3B82F6)];
  static const List<Color> _pink = <Color>[Color(0xFFF9A8D4), Color(0xFFDB2777)];
  static const List<Color> _green = <Color>[Color(0xFF6EE7B7), Color(0xFF059669)];
  static const List<Color> _violet = <Color>[Color(0xFFC4B5FD), Color(0xFF7C3AED)];
  static const List<Color> _amber = <Color>[Color(0xFFFCD34D), Color(0xFFF59E0B)];
  static const List<Color> _orange = <Color>[Color(0xFFFDBA74), Color(0xFFEA580C)];
  static const List<Color> _teal = <Color>[Color(0xFF5EEAD4), Color(0xFF0D9488)];
  static const List<Color> _indigo = <Color>[Color(0xFFA5B4FC), Color(0xFF4F46E5)];
  static const List<Color> _sky = <Color>[Color(0xFF67E8F9), Color(0xFF0891B2)];
  static const List<Color> _red = <Color>[Color(0xFFFCA5A5), Color(0xFFDC2626)];

  static final Map<int, List<Color>> _byIcon = <int, List<Color>>{
    Icons.person_rounded.codePoint: _rose,
    Icons.person_outline_rounded.codePoint: _rose,
    Icons.boy_rounded.codePoint: _blue,
    Icons.girl_rounded.codePoint: _pink,
    Icons.man_rounded.codePoint: _green,
    Icons.woman_rounded.codePoint: _violet,
    Icons.people_alt_rounded.codePoint: _amber,
    Icons.people_outline_rounded.codePoint: _indigo,
    Icons.volunteer_activism_rounded.codePoint: _violet,
    Icons.family_restroom_rounded.codePoint: _orange,
    Icons.shield_rounded.codePoint: _teal,
    Icons.calendar_month_rounded.codePoint: _orange,
    Icons.calendar_today_rounded.codePoint: _orange,
    Icons.cake_rounded.codePoint: _pink,
    Icons.mosque_rounded.codePoint: _green,
    Icons.church_rounded.codePoint: _indigo,
    Icons.temple_hindu_rounded.codePoint: _orange,
    Icons.self_improvement_rounded.codePoint: _amber,
    Icons.diversity_3_rounded.codePoint: _teal,
    Icons.translate_rounded.codePoint: _sky,
    Icons.public_rounded.codePoint: _sky,
    Icons.location_on_rounded.codePoint: _red,
    Icons.map_rounded.codePoint: _teal,
    Icons.location_city_rounded.codePoint: _indigo,
    Icons.contact_phone_rounded.codePoint: _blue,
    Icons.smartphone_rounded.codePoint: _blue,
    Icons.mail_rounded.codePoint: _violet,
    Icons.account_tree_rounded.codePoint: _teal,
    Icons.groups_rounded.codePoint: _teal,
    Icons.school_rounded.codePoint: _indigo,
    Icons.menu_book_rounded.codePoint: _violet,
    Icons.auto_stories_rounded.codePoint: _violet,
    Icons.workspace_premium_rounded.codePoint: _amber,
    Icons.category_rounded.codePoint: _sky,
    Icons.account_balance_rounded.codePoint: _indigo,
    Icons.check_circle_outline_rounded.codePoint: _green,
    Icons.straighten_rounded.codePoint: _sky,
    Icons.height_rounded.codePoint: _sky,
    Icons.eco_outlined.codePoint: _green,
    Icons.kebab_dining_rounded.codePoint: _orange,
    Icons.restaurant_rounded.codePoint: _orange,
    Icons.work_rounded.codePoint: _blue,
    Icons.account_balance_wallet_rounded.codePoint: _green,
    Icons.lock_person_rounded.codePoint: _indigo,
    Icons.photo_camera_rounded.codePoint: _pink,
    Icons.edit_note_rounded.codePoint: _violet,
    Icons.verified_user_rounded.codePoint: _green,
    Icons.badge_rounded.codePoint: _blue,
    Icons.interests_rounded.codePoint: _amber,
    Icons.home_rounded.codePoint: _orange,
    Icons.favorite_rounded.codePoint: _rose,
    Icons.favorite_border_rounded.codePoint: _rose,
    Icons.heart_broken_rounded.codePoint: _red,
    Icons.hourglass_bottom_rounded.codePoint: _amber,
    Icons.add_rounded.codePoint: _teal,
    Icons.lightbulb_rounded.codePoint: _amber,
    Icons.tips_and_updates_rounded.codePoint: _amber,
  };

  static const List<List<Color>> _cycle = <List<Color>>[
    _rose, _blue, _green, _violet, _amber, _teal, _orange, _indigo, _sky, _pink,
  ];

  /// The gradient a glyph is drawn on.
  static List<Color> colorsFor(IconData icon) =>
      _byIcon[icon.codePoint] ?? _cycle[icon.codePoint % _cycle.length];

  @override
  Widget build(BuildContext context) {
    final List<Color> c = colorsFor(icon);
    final double radius = size * 0.32;
    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.last.withValues(alpha: soft && !selected ? 0.22 : 0.35),
              blurRadius: size * 0.3,
              offset: Offset(0, size * 0.12),
              spreadRadius: -size * 0.06,
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}

/// Large hero version shown above each step title: the badge sitting inside
/// a faint blush halo.
class RegHeroIcon extends StatelessWidget {
  const RegHeroIcon({super.key, required this.icon, this.size = 68});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, double s, Widget? child) => Transform.scale(scale: s, child: child),
        child: Container(
          padding: EdgeInsets.all(size * 0.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RegIconBadge.colorsFor(icon).first.withValues(alpha: 0.18),
          ),
          child: RegIconBadge(icon: icon, size: size),
        ),
      ),
    );
  }
}
