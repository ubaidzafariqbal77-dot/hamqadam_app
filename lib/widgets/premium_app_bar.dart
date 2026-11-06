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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  static const Color _ink = Color(0xFF8E3D60);

  @override
  Widget build(BuildContext context) {
    // Soft white-to-blush sheet with rounded bottom corners, a hairline rose
    // edge and a faint rose glow. Leading/action icons sit in blush circle
    // chips; the title is the app's serif in near-black with a rose subtitle.
    final ThemeData base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFBE3EC),
            foregroundColor: _ink,
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
        ),
      ),
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight + 10,
        centerTitle: centerTitle,
        leading: leading == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 12), child: Center(child: leading)),
        leadingWidth: leading == null ? null : 56,
        iconTheme: const IconThemeData(color: _ink, size: 22),
        actionsIconTheme: const IconThemeData(color: _ink, size: 22),
        actionsPadding: const EdgeInsets.only(right: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Colors.white, Color(0xFFFFF1F6)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
            border: Border(
              bottom: BorderSide(color: const Color(0xFFF4BFD1).withValues(alpha: 0.7)),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1FB25C82),
                blurRadius: 20,
                offset: Offset(0, 6),
                spreadRadius: -4,
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
              style: AppTextStyles.displaySerif.copyWith(
                color: const Color(0xFF151515),
                fontSize: 21,
                height: 1.15,
              ),
            ),
            if ((subtitle ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFB25C82),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ],
        ),
        actions: actions == null
            ? null
            : <Widget>[
                for (final Widget a in actions!)
                  Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ],
      ),
    );
  }
}
