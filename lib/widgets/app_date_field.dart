import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';

/// Tappable date field: label above, value with a trailing calendar glyph, and
/// the reference wheel-style date sheet on tap — "Cancel · Select Date of
/// Birth · Confirm" with Month / Day / Year columns and a soft pink selection
/// band across the centred row.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.requirement = FieldRequirement.required,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.hint = 'Select date',
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final FieldRequirement requirement;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;
  final String hint;

  /// Reference mockup format: "Aug 12, 1994".
  static final DateFormat _fmt = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor = (errorText ?? '').isNotEmpty
        ? AppColors.error
        : dark
        ? AppColors.requiredFieldBorderDark
        : Theme.of(context).colorScheme.primary;
    // Label inside the card above the date, like every other field in the
    // registration flow (the references' Education field card).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            decoration: BoxDecoration(
              color: dark
                  ? AppColors.requiredFieldBackgroundDark
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      BiText.inline(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: dark
                              ? AppColors.darkTextSecondary
                              : AppColors.fieldLabelRose,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value == null ? hint : _fmt.format(value!),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: value == null
                              ? Theme.of(context).hintColor
                              : (dark
                                    ? AppColors.darkInputText
                                    : AppColors.lightInputText),
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing calendar glyph — the reference's pink calendar disc.
                Icon(
                  Icons.calendar_month_rounded,
                  size: AppDimensions.iconMd,
                  color: borderColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime first = firstDate ?? DateTime(1950);
    final DateTime last = lastDate ?? now;
    DateTime temp = value ?? DateTime(now.year - 25, now.month, now.day);
    if (temp.isBefore(first)) temp = first;
    if (temp.isAfter(last)) temp = last;

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          _WheelDateSheet(initial: temp, first: first, last: last),
    );
    if (picked != null) onChanged(picked);
  }
}

/// The reference date sheet: rounded top corners, a grab handle, the
/// "Cancel — Select Date of Birth — Confirm" header row, and three wheels
/// (Month / Day / Year) under column captions with a pink band behind the
/// selected row.
class _WheelDateSheet extends StatefulWidget {
  const _WheelDateSheet({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_WheelDateSheet> createState() => _WheelDateSheetState();
}

class _WheelDateSheetState extends State<_WheelDateSheet> {
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;
  late int _year = widget.initial.year;

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  DateTime get _selected {
    final int day = _day.clamp(1, _daysInMonth);
    DateTime d = DateTime(_year, _month, day);
    if (d.isBefore(widget.first)) d = widget.first;
    if (d.isAfter(widget.last)) d = widget.last;
    return d;
  }

  void _clampDay() {
    if (_day > _daysInMonth) setState(() => _day = _daysInMonth);
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = dark ? AppColors.darkSurface : Colors.white;
    final Color ink = dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color muted = dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // ---- Header: Cancel · title · Confirm --------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Select Date of Birth',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(color: ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      'Confirm',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---- Column captions -------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: Text(
                        'Month',
                        style: AppTextStyles.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Day',
                        style: AppTextStyles.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Year',
                        style: AppTextStyles.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---- Wheels ------------------------------------------------------
            SizedBox(
              height: 216,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Soft pink band across the selected row (reference style).
                  Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: dark
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.18)
                          : const Color(0xFFF7D3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _wheel(
                          child: CupertinoPicker(
                            key: const ValueKey<int>(1),
                            scrollController: FixedExtentScrollController(
                              initialItem: _month - 1,
                            ),
                            itemExtent: 44,
                            looping: true,
                            selectionOverlay: const SizedBox.shrink(),
                            onSelectedItemChanged: (int i) => setState(() {
                              _month = i + 1;
                              _clampDay();
                            }),
                            children: <Widget>[
                              for (final String m in _months)
                                Center(
                                  child: Text(
                                    m,
                                    style: _wheelStyle(
                                      _months[_month - 1] == m,
                                      ink,
                                      muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          child: CupertinoPicker(
                            key: const ValueKey<int>(2),
                            scrollController: FixedExtentScrollController(
                              initialItem: _day - 1,
                            ),
                            itemExtent: 44,
                            looping: true,
                            selectionOverlay: const SizedBox.shrink(),
                            onSelectedItemChanged: (int i) =>
                                setState(() => _day = i + 1),
                            children: <Widget>[
                              for (int d = 1; d <= 31; d++)
                                Center(
                                  child: Text(
                                    '$d',
                                    style: _wheelStyle(d == _day, ink, muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          child: CupertinoPicker(
                            key: const ValueKey<int>(3),
                            scrollController: FixedExtentScrollController(
                              initialItem: (_year - widget.first.year).clamp(
                                0,
                                widget.last.year - widget.first.year,
                              ),
                            ),
                            itemExtent: 44,
                            onSelectedItemChanged: (int i) => setState(() {
                              _year = widget.first.year + i;
                              _clampDay();
                            }),
                            children: <Widget>[
                              for (
                                int y = widget.first.year;
                                y <= widget.last.year;
                                y++
                              )
                                Center(
                                  child: Text(
                                    '$y',
                                    style: _wheelStyle(y == _year, ink, muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _wheel({required Widget child}) => SizedBox(height: 216, child: child);

  /// Selected rows are bold ink; the rest muted — exactly the mockup's weight
  /// shift. Days beyond the current month's length grey out via clamping.
  TextStyle _wheelStyle(bool selected, Color ink, Color muted) =>
      AppTextStyles.body.copyWith(
        fontSize: selected ? 19 : 17,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: selected ? ink : muted,
      );
}
