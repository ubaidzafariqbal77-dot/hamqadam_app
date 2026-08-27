import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/app_button.dart';

/// Modal dialog for reporting a chat thread.
class ChatReportDialog extends StatefulWidget {
  const ChatReportDialog({super.key, required this.thread});

  final ChatThread thread;

  static Future<void> show(BuildContext context, ChatThread thread) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => ChatReportDialog(thread: thread),
    );
  }

  @override
  State<ChatReportDialog> createState() => _ChatReportDialogState();
}

class _ChatReportDialogState extends State<ChatReportDialog> {
  final ChatController _chatCtrl = Get.find<ChatController>();

  static const List<String> _reasons = <String>[
    'Unwanted messages',
    'Inappropriate language or harassment',
    'Scam or commercial spam',
    'Fake identity / Impersonation',
    'Other reason',
  ];

  String _selectedReason = _reasons.first;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await _chatCtrl.reportChat(_selectedReason);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Report Chat', style: AppTextStyles.title),
                      Text(
                        'Report conversation with ${widget.thread.participant.name}',
                        style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.lightDivider),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Select a reason for reporting:',
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xs),
            ..._reasons.map((String r) {
              final bool isSelected = _selectedReason == r;
              return InkWell(
                onTap: () => setState(() => _selectedReason = r),
                borderRadius: AppRadius.smAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primary : theme.hintColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reporting will notify moderation and block further messages from this user.',
              style: AppTextStyles.caption.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Report & Block',
                    variant: AppButtonVariant.destructive,
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
