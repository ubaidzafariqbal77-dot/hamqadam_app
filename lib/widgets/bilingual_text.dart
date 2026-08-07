import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_urdu.dart';

/// Toggles bilingual (Urdu) rendering for a whole subtree.
///
/// [BiText] reads the nearest scope: when it resolves to `false`, only the
/// English line is shown. With no scope present the default is `true`
/// (bilingual), so the rest of the app is unaffected. Used to keep the login
/// screen English-only except for the email/password/phone fields, which are
/// wrapped in `UrduScope(enabled: true)`.
class UrduScope extends InheritedWidget {
  const UrduScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UrduScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(UrduScope oldWidget) => enabled != oldWidget.enabled;
}

/// Renders a piece of copy in BOTH languages.
///
/// Two layouts:
///  • **stacked** (default) — English on top, Urdu (Noto Nastaliq) beneath it.
///    Used for titles, subtitles, notes and field labels.
///  • **inline** — a single line `English / اردو`. Used for buttons and field
///    placeholders, matching the product design references.
///
/// If no Urdu translation exists for [text], only the English line is shown, so
/// this is always safe as a drop-in replacement for a plain [Text].
class BiText extends StatelessWidget {
  const BiText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.urduColor,
    this.gap = 2,
    this.showUrdu = true,
    this.inline = false,
  });

  /// Inline convenience constructor: `English / اردو` on one line.
  const BiText.inline(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.urduColor,
    this.showUrdu = true,
  })  : gap = 0,
        inline = true;

  /// The English source string (also used as the translation lookup key).
  final String text;

  /// Base style for the English text. The Urdu part is derived from it.
  final TextStyle style;

  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Optional override for the Urdu colour; defaults to a muted English colour.
  final Color? urduColor;

  /// Vertical spacing between the English and Urdu lines (stacked mode only).
  final double gap;

  /// Allows callers to force English-only (e.g. dynamic/interpolated strings).
  final bool showUrdu;

  /// When true, renders `English / اردو` on a single line instead of stacking.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final String? ur = (showUrdu && UrduScope.of(context)) ? AppUrdu.of(text) : null;

    if (ur == null || ur.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final Color baseColor =
        style.color ?? DefaultTextStyle.of(context).style.color ?? AppColors.lightTextPrimary;
    // Urdu renders in the SAME primary colour as its English counterpart (no
    // muting) so both languages read at full strength. Callers may still pass
    // an explicit [urduColor] where a different tint is intended (e.g. white
    // text on the brand gradient header).
    final Color urColor = urduColor ?? baseColor;

    if (inline) {
      final double size = style.fontSize ?? 15;
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: text, style: style),
            TextSpan(
              text: '  |  ',
              style: style.copyWith(color: baseColor.withValues(alpha: 0.4)),
            ),
            TextSpan(
              text: ur,
              style: style.copyWith(
                fontFamily: AppTextStyles.urduFont,
                fontSize: size * 0.96,
                height: 1.0,
                color: urColor,
              ),
            ),
          ],
        ),
        textAlign: textAlign ?? TextAlign.center,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Centered copy (titles/subtitles) stacks centered; everything else keeps
    // English on the LEFT (LTR) and Urdu on the RIGHT (RTL) so each language
    // sits on its natural side — a clean, balanced bilingual block.
    final bool centered = textAlign == TextAlign.center;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          text,
          style: style,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          maxLines: maxLines,
          overflow: overflow,
        ),
        SizedBox(height: gap),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            ur,
            style: AppTextStyles.urdu(style, color: urColor),
            textAlign: centered ? TextAlign.center : TextAlign.right,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
      ],
    );
  }
}
