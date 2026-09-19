import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

/// A single selectable card. [image] points at an asset shown inside the soft
/// pink disc (marital-status reference style); [icon] is the fallback when the
/// image is missing, and [description] is an optional muted line under the
/// label (diet cards).
class CardOption {
  const CardOption(
    this.value,
    this.label, {
    this.icon,
    this.image,
    this.photo,
    this.photoIcon,
    this.description,
  });
  final Object value;
  final String label;
  final IconData? icon;

  /// Optional asset image rendered inside the card's icon disc.
  final String? image;

  /// Optional large image for a photo-style selection card.
  final String? photo;

  /// Icon shown below the photo and used if that image cannot be loaded.
  final IconData? photoIcon;

  /// Optional muted line under the label (e.g. "Plant-based diet").
  final String? description;
}

/// Premium single-select card grid matching the marital-status reference:
/// two tall cards per row, a large soft-pink disc holding the option's image
/// (or icon) above a centered bilingual label. The selected card fills with
/// the brand pink and its disc turns white-on-pink, like the mockup's
/// "Never Married" state. The last odd card spans full width.
class AppCardSelector extends StatelessWidget {
  const AppCardSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.label,
  });

  final List<CardOption> options;
  final Object? selected;
  final ValueChanged<CardOption> onSelect;

  /// Optional centered question label shown above the grid.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    if (label != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BiText(
            label!,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 17),
          ),
        ),
      );
    }
    for (int i = 0; i < options.length; i += 2) {
      final bool hasPair = i + 1 < options.length;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // A lone last card spans the full width (like the mockup); paired
              // cards split the row evenly.
              Expanded(child: _card(context, options[i])),
              if (hasPair) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _card(context, options[i + 1])),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < options.length) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return Column(children: rows);
  }

  Widget _card(BuildContext context, CardOption o) {
    final bool isSelected = selected == o.value;
    final bool hasPhoto = o.photo != null;
    final bool filledSelection = isSelected && !hasPhoto;
    final double cardRadius = hasPhoto ? 14 : 18;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = dark ? AppColors.darkSurface : Colors.white;
    final Color lineColor = dark
        ? AppColors.darkBorder
        : const Color(0xFFF3D7E1);
    final Color labelColor =
        Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.lightTextPrimary;
    final Color discColor = filledSelection
        ? Colors.white.withValues(alpha: 0.28)
        : dark
        ? AppColors.primary.withValues(alpha: 0.14)
        : const Color(0xFFF9DCE7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: () => onSelect(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: hasPhoto
              ? const EdgeInsets.fromLTRB(10, 12, 10, 16)
              : const EdgeInsets.fromLTRB(16, 26, 16, 24),
          decoration: BoxDecoration(
            color: filledSelection ? AppColors.primary : base,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: isSelected ? AppColors.primary : lineColor,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFB4487B).withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Photo-card variant (Physical reference): a big rounded photo
              // on top with a check badge when selected, a small pink icon
              // disc, then the bold label + description.
              if (hasPhoto) ...<Widget>[
                Stack(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            o.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, Object __, StackTrace? ___) =>
                                Container(
                                  color: discColor,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    o.photoIcon ??
                                        o.icon ??
                                        Icons.restaurant_rounded,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0B8C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : const Color(0xFFF9DCE7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    o.photoIcon ?? Icons.restaurant_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                BiText(
                  o.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 16.5,
                    color: isSelected ? AppColors.primaryDark : labelColor,
                  ),
                ),
                if (o.description != null) ...<Widget>[
                  const SizedBox(height: 3),
                  BiText(
                    o.description!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      color: labelColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ] else ...<Widget>[
                // Icon disc: the option's artwork floating in a soft pink circle.
                // Options without artwork (e.g. diet) render as label-only cards.
                if (o.image != null || o.icon != null) ...<Widget>[
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: discColor,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: o.image != null
                        ? Image.asset(
                            o.image!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, Object __, StackTrace? ___) =>
                                Icon(
                                  o.icon ?? Icons.person_rounded,
                                  size: 34,
                                  color: AppColors.primary,
                                ),
                          )
                        : Icon(
                            o.icon!,
                            size: 34,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                  ),
                  const SizedBox(height: 18),
                ],
                BiText(
                  o.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 15.5,
                    color: isSelected ? Colors.white : labelColor,
                  ),
                ),
                if (o.description != null) ...<Widget>[
                  const SizedBox(height: 4),
                  BiText(
                    o.description!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : labelColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
