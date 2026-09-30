import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

/// Preferred religion / sect — the "Group 2" reference's disc grid: each faith
/// sits in a BIG soft-pink 3D symbol disc with its label beneath in the
/// "Islam · Crescent" style, under the reference's two-line header
/// ("All faiths represented / Symbols included for shared respect &
/// understanding"). This replaces the bordered square-tile cards, which read
/// as option rows rather than the reference's friendly discs.
///
/// Only the religions that have 3D artwork in [RegIcons.religionRowArt] are
/// drawn as discs; anything else in the server list stays reachable through
/// the "full list" picker beside the grid.
class FaithDiscGrid extends StatelessWidget {
  const FaithDiscGrid({
    super.key,
    required this.items,
    required this.artFor,
    required this.selectedId,
    required this.onSelect,
    this.symbolNames = const <int, String>{},
  });

  /// The religions shown as discs (first six of the server list in practice).
  final List<FaithOption> items;

  /// `religion_id → asset path` for the 3D symbol inside each disc.
  final String? Function(int id) artFor;

  final int? selectedId;
  final ValueChanged<FaithOption> onSelect;

  /// `religion_id → symbol word` for the "Islam · Crescent" sub-label.
  final Map<int, String> symbolNames;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Reference header ────────────────────────────────────────────
        BiText(
          'All faiths represented',
          textAlign: TextAlign.center,
          style: AppTextStyles.displaySerif.copyWith(
            fontSize: 20,
            color: dark ? AppColors.darkTextPrimary : AppColors.partnerSectionInk,
          ),
        ),
        const SizedBox(height: 5),
        BiText(
          'Symbols included for shared respect & understanding',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            fontSize: 13.5,
            color: (dark ? AppColors.darkTextPrimary : AppColors.partnerSectionInk)
                .withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 20),

        // ── Disc grid: two soft discs per row ───────────────────────────
        for (int i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _FaithDisc(
                    item: items[i],
                    art: artFor(items[i].id),
                    symbol: symbolNames[items[i].id],
                    selected: selectedId == items[i].id,
                    dark: dark,
                    onTap: () => onSelect(items[i]),
                  ),
                ),
                if (i + 1 < items.length) ...<Widget>[
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FaithDisc(
                      item: items[i + 1],
                      art: artFor(items[i + 1].id),
                      symbol: symbolNames[items[i + 1].id],
                      selected: selectedId == items[i + 1].id,
                      dark: dark,
                      onTap: () => onSelect(items[i + 1]),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

/// One religion surfaced as a plain [FaithOption]-shaped value for the grid.
class FaithOption {
  const FaithOption(this.id, this.name);
  final int id;
  final String name;
}

class _FaithDisc extends StatelessWidget {
  const _FaithDisc({
    required this.item,
    required this.art,
    required this.selected,
    required this.dark,
    required this.onTap,
    this.symbol,
  });

  final FaithOption item;
  final String? art;
  final String? symbol;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  /// The reference's symbol word for the sub-label, matched on the server's
  /// wording rather than list position so a rename keeps the right mark.
  static const Map<String, String> _symbols = <String, String>{
    'islam': 'Crescent',
    'christianity': 'Cross',
    'christian': 'Cross',
    'hinduism': 'Om',
    'hindu': 'Om',
    'sikhism': 'Khanda',
    'sikh': 'Khanda',
    'judaism': 'Star of David',
    'jewish': 'Star of David',
    'other': 'Star',
    'interfaith': 'Star',
  };

  String get _symbolWord =>
      symbol ??
      _symbols.entries
          .where((MapEntry<String, String> e) => item.name.toLowerCase().contains(e.key))
          .map((MapEntry<String, String> e) => e.value)
          .firstOrNull ??
      'Symbol';

  @override
  Widget build(BuildContext context) {
    // The 3D assets are square JPEGs on white, so the disc renders white in
    // light mode (same trick AppCardSelector uses) — the reference's big
    // "soft-pink disc" impression comes from the ring + glow around it.
    final Color ring = selected
        ? AppColors.primary
        : (dark ? AppColors.primaryLight.withValues(alpha: 0.30) : const Color(0xFFF7D3E0));
    const double discSize = 118;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Soft outer glow — the reference's big pink disc.
                Container(
                  width: discSize + 14,
                  height: discSize + 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        AppColors.primary.withValues(alpha: selected ? 0.22 : 0.10),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: discSize,
                  height: discSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? AppColors.darkSurfaceAlt : Colors.white,
                    border: Border.all(color: ring, width: selected ? 2.4 : 1.4),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: selected ? 0.30 : 0.12),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: art != null
                        ? Image.asset(
                            art!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, Object __, StackTrace? ___) => const Icon(
                              Icons.auto_awesome_outlined,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_outlined,
                            size: 40,
                            color: AppColors.primary,
                          ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 2,
                    right: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // "Islam · Crescent" — reference label style.
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: item.name),
                  const TextSpan(text: '  ·  '),
                  TextSpan(
                    text: _symbolWord,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: (dark
                              ? AppColors.darkTextPrimary
                              : AppColors.partnerSectionInk)
                          .withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 14.5,
                color: selected
                    ? AppColors.primary
                    : (dark ? AppColors.darkTextPrimary : AppColors.partnerSectionInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
