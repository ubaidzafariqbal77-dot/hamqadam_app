import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// Premium gradient AppBar with a softly rounded bottom edge, elegant shadow
/// and white content. Drop-in for `Scaffold.appBar`.
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
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x33D6185E),
              blurRadius: 18,
              offset: Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
      ),
      title: Column(
        crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: AppTextStyles.title.copyWith(color: Colors.white)),
          if ((subtitle ?? '').isNotEmpty)
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
        ],
      ),
      actions: actions,
    );
  }
}
