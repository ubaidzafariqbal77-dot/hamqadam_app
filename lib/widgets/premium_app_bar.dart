import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// The Discover screen's white reference AppBar, now app-wide.
///
/// Every screen used to draw the dusty-rose gradient bar; the Discover
/// redesign moved to the HTML reference's sticky white header — serif pink
/// title, gray subtitle, soft-pink icon chips — and the same treatment now
/// applies everywhere so the app reads as one family again. Dark text on
/// white, a hairline shadow, and actions drawn in the soul-pink ink.
///
/// Drop-in for `Scaffold.appBar` — the constructor is unchanged, so no call
/// site needed edits.
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PremiumAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      iconTheme: const IconThemeData(color: Color(0xFFFF0F4D)),
      actionsIconTheme: const IconThemeData(color: Color(0xFFFF0F4D)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
          boxShadow: <BoxShadow>[
            // The reference header's soft drop: a faint neutral shadow
            // (the old rose glow read as a dirty smear under the white bar).
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
      ),
      title: Column(
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: AppTextStyles.title.copyWith(
              color: const Color(0xFF151515),
              fontSize: 18,
            ),
          ),
          if ((subtitle ?? '').isNotEmpty)
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF9CA3AF),
                fontSize: 11,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}
