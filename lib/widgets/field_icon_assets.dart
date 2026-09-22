import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// An [IconData]-compatible image glyph.
///
/// The registration fields accept Material [IconData] as leading artwork, and
/// [IconTheme] would normally not touch an [Image]. Wrapping the asset in a
/// [SizedBox] + [RawImage] instead of [Image.asset] keeps it out of the
/// IconTheme data flow, so the 3D faith symbols (crescent, cross, Om, Khanda,
/// Star of David) render exactly as drawn instead of being recoloured.
class AssetGlyph extends StatelessWidget {
  const AssetGlyph(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        // A missing asset shows an empty slot rather than red error squares —
        // the artwork is decorative, never load-bearing.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Rose line-art mail envelope, drawn in the same single-stroke style as the
/// reference's location pin / heart icons. The icon set has no envelope
/// artwork, so the Email field draws its own to stay on-style.
class MailGlyph extends StatelessWidget {
  const MailGlyph({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MailPainter(c)),
    );
  }
}

class _MailPainter extends CustomPainter {
  const _MailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.20,
      size.width * 0.84,
      size.height * 0.60,
    );
    final RRect body = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.10));
    canvas.drawRRect(body, paint);

    final Path flap = Path()
      ..moveTo(rect.left + size.width * 0.06, rect.top + size.height * 0.10)
      ..lineTo(rect.center.dx, rect.top + rect.height * 0.52)
      ..lineTo(rect.right - size.width * 0.06, rect.top + size.height * 0.10);
    canvas.drawPath(flap, paint);
  }

  @override
  bool shouldRepaint(_MailPainter old) => old.color != color;
}

/// Rose line-art handset, matching the flat rose style of the identified
/// location-pin artwork (WA4002).
class PhoneGlyph extends StatelessWidget {
  const PhoneGlyph({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PhonePainter(c)),
    );
  }
}

class _PhonePainter extends CustomPainter {
  const _PhonePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Classic handset silhouette scaled to the square.
    final Path p = Path();
    final double k = size.width / 24;
    p.moveTo(4.2 * k, 4.6 * k);
    p.cubicTo(3.4 * k, 5.5 * k, 3.0 * k, 7.0 * k, 3.3 * k, 8.6 * k);
    p.cubicTo(4.0 * k, 12.6 * k, 6.4 * k, 16.4 * k, 9.6 * k, 19.0 * k);
    p.cubicTo(11.9 * k, 20.8 * k, 14.8 * k, 21.4 * k, 17.4 * k, 20.7 * k);
    p.cubicTo(18.7 * k, 20.3 * k, 19.8 * k, 19.4 * k, 20.2 * k, 18.3 * k);
    p.cubicTo(20.5 * k, 17.5 * k, 20.3 * k, 16.7 * k, 19.7 * k, 16.2 * k);
    p.lineTo(16.9 * k, 14.1 * k);
    p.cubicTo(16.3 * k, 13.7 * k, 15.5 * k, 13.7 * k, 14.9 * k, 14.2 * k);
    p.lineTo(13.6 * k, 15.2 * k);
    p.cubicTo(11.9 * k, 14.3 * k, 10.0 * k, 12.5 * k, 9.0 * k, 10.6 * k);
    p.lineTo(10.0 * k, 9.2 * k);
    p.cubicTo(10.5 * k, 8.6 * k, 10.5 * k, 7.8 * k, 10.0 * k, 7.2 * k);
    p.lineTo(8.0 * k, 4.5 * k);
    p.cubicTo(7.4 * k, 3.7 * k, 6.2 * k, 3.5 * k, 5.3 * k, 3.9 * k);
    p.close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_PhonePainter old) => old.color != color;
}

/// The standard soft-pink field disc, holding either Material [icon], an
/// asset [image], or a custom [child] glyph (e.g. [PhoneGlyph]/[MailGlyph]).
/// All keep their own artwork colours inside the disc.
class AssetOrIconDisc extends StatelessWidget {
  const AssetOrIconDisc({
    super.key,
    this.icon,
    this.image,
    this.child,
    this.size = 44,
  });

  final IconData? icon;
  final String? image;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark
            ? AppColors.primary.withValues(alpha: 0.16)
            : const Color(0xFFF9DCE7),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.22),
      child: child ??
          (image != null
              ? AssetGlyph(image!, size: size * 0.56)
              : Icon(
                  icon ?? Icons.edit_note_rounded,
                  size: size * 0.56,
                  color: AppColors.primary,
                )),
    );
  }
}
