import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../models/message_template_model.dart';

/// Selectable list of admin-managed templates. Each card shows the title and
/// opening; the selected one expands to the complete message so the member
/// previews exactly what will be sent (spec §6).
class MessageTemplatePicker extends StatelessWidget {
  const MessageTemplatePicker({
    super.key,
    required this.templates,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MessageTemplate> templates;
  final String? selectedId;
  final ValueChanged<MessageTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'No messages are available right now. Please try again later.',
          style: AppTextStyles.body.copyWith(color: theme.hintColor),
        ),
      );
    }

    return Column(
      children: templates.map((MessageTemplate t) {
        final bool selected = t.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => onSelected(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.07)
                    : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface),
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? AppColors.primary : theme.hintColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(t.title, style: AppTextStyles.bodyStrong),
                        const SizedBox(height: 4),
                        Text(
                          selected ? t.fullText : t.opening,
                          maxLines: selected ? null : 2,
                          overflow: selected ? null : TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            height: 1.45,
                            color: selected ? null : theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Final preview with an explicit confirm — nothing is sent without it
/// (spec §2 Stage 1 and Stage 3, §6).
Future<bool> confirmMessageSend(
  BuildContext context, {
  required String title,
  required String recipientName,
  required String message,
  required String confirmLabel,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      title: Text(title, style: AppTextStyles.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'To: $recipientName',
              style: AppTextStyles.caption.copyWith(color: Theme.of(ctx).hintColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: AppRadius.mdAll,
              ),
              child: Text(message, style: AppTextStyles.body.copyWith(height: 1.5)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Edit')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}
