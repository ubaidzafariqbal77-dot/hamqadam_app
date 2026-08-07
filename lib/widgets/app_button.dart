import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

enum AppButtonVariant { primary, secondary, outline, destructive }

/// Premium button: gradient primary with a soft brand glow, press-scale
/// animation, ripple, loading & disabled states, optional icon and full-width
/// layout. Public API is unchanged so existing callers keep working.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.enabled = true,
    this.icon,
    this.fullWidth = true,
    this.height = AppDimensions.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool enabled;
  final IconData? icon;
  final bool fullWidth;
  final double height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _disabled => !widget.enabled || widget.loading || widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final bool isGradient = widget.variant == AppButtonVariant.primary && !_disabled;
    final Color fg = _foreground(context);

    final Widget content = widget.loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: AppDimensions.iconMd, color: fg),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: BiText.inline(
                  widget.label,
                  style: AppTextStyles.button.copyWith(color: fg),
                  urduColor: fg.withValues(alpha: 0.92),
                ),
              ),
            ],
          );

    // Soft coloured glow beneath solid/gradient buttons (not outline).
    final List<BoxShadow> glow = (_disabled || widget.variant == AppButtonVariant.outline)
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: _glowColor().withValues(alpha: _pressed ? 0.20 : 0.38),
              blurRadius: _pressed ? 10 : 20,
              offset: Offset(0, _pressed ? 3 : 9),
              spreadRadius: -2,
            ),
          ];

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.fullWidth ? double.infinity : null,
        height: widget.height,
        decoration: BoxDecoration(borderRadius: AppRadius.lgAll, boxShadow: glow),
        child: Material(
          color: isGradient ? Colors.transparent : _background(context),
          borderRadius: AppRadius.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: _disabled ? null : widget.onPressed,
            onHighlightChanged: (bool v) {
              if (mounted && !_disabled) setState(() => _pressed = v);
            },
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isGradient
                    ? const LinearGradient(
                        colors: AppColors.brandGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                borderRadius: AppRadius.lgAll,
                border: widget.variant == AppButtonVariant.outline
                    ? Border.all(
                        color: _disabled ? Theme.of(context).dividerColor : AppColors.primary,
                        width: 1.5,
                      )
                    : null,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _glowColor() {
    switch (widget.variant) {
      case AppButtonVariant.secondary:
        return AppColors.gold;
      case AppButtonVariant.destructive:
        return AppColors.error;
      case AppButtonVariant.primary:
      case AppButtonVariant.outline:
        return AppColors.primary;
    }
  }

  Color _background(BuildContext context) {
    if (_disabled) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceAlt
          : AppColors.lightSurfaceAlt;
    }
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.gold;
      case AppButtonVariant.outline:
        return Colors.transparent;
      case AppButtonVariant.destructive:
        return AppColors.error;
    }
  }

  Color _foreground(BuildContext context) {
    if (_disabled) {
      return Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.lightTextSecondary;
    }
    switch (widget.variant) {
      case AppButtonVariant.outline:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return Colors.white;
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
        return Colors.white;
    }
  }
}
