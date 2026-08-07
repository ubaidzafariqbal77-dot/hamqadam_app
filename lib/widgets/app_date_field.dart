import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';

/// Tappable date field that opens a premium date-picker dialog.
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

  static final DateFormat _fmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return FormFieldContainer(
      label: label,
      requirement: requirement,
      errorText: errorText,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: InkWell(
        onTap: () => _pick(context),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.calendar_today_rounded,
              size: AppDimensions.iconSm,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value == null ? hint : _fmt.format(value!),
                style: AppTextStyles.body.copyWith(
                  color: value == null ? Theme.of(context).hintColor : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime first = firstDate ?? DateTime(1950);
    final DateTime last = lastDate ?? now;
    DateTime temp = value ?? DateTime(now.year - 25, now.month, now.day);
    if (temp.isBefore(first)) temp = first;
    if (temp.isAfter(last)) temp = last;

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color textPrimary =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.lightTextPrimary;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (BuildContext ctx) {
        DateTime selected = temp;
        final DateFormat headerFmt = DateFormat('EEE, dd MMM yyyy');

        return Dialog(
          backgroundColor: surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
          clipBehavior: Clip.antiAlias,
          child: StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ---- Premium gradient header --------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.brandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.cake_rounded, color: Colors.white, size: 26),
                        const SizedBox(height: AppSpacing.xs),
                        BiText(
                          'Date of birth',
                          textAlign: TextAlign.center,
                          gap: 0,
                          style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                          urduColor: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 4),
                        // Live preview of the currently-scrolled date.
                        Text(
                          headerFmt.format(selected),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---- Centered wheel picker ----------------------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SizedBox(
                      height: 200,
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: dark ? Brightness.dark : Brightness.light,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: AppTextStyles.body.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: temp,
                          minimumDate: first,
                          maximumDate: last,
                          onDateTimeChanged: (DateTime d) => setState(() => selected = d),
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // ---- Actions ------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: BiText.inline('Cancel', style: AppTextStyles.button),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(selected),
                            child: BiText.inline(
                              'Confirm',
                              style: AppTextStyles.button.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }
}
