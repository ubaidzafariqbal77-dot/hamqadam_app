import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';

/// Modal dialog for reporting a profile.
class ReportProfileDialog extends StatefulWidget {
  const ReportProfileDialog({super.key, required this.profile});

  final SearchProfileModel profile;

  static Future<void> show(BuildContext context, SearchProfileModel profile) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => ReportProfileDialog(profile: profile),
    );
  }

  @override
  State<ReportProfileDialog> createState() => _ReportProfileDialogState();
}

class _ReportProfileDialogState extends State<ReportProfileDialog> {
  static const List<String> _reasons = <String>[
    'Inappropriate photos or bio',
    'Fake profile / Impersonation',
    'Offensive behavior or harassment',
    'Scam or commercial activity',
    'Other reason',
  ];

  String _selectedReason = _reasons.first;
  final TextEditingController _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      Navigator.of(context).pop();
      AppSnackbar.success('Report submitted. Our moderation team will review this profile.');
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
                      Text('Report Profile', style: AppTextStyles.title),
                      Text(
                        'Report ${widget.profile.displayName}',
                        style: AppTextStyles.caption.copyWith(color: theme.hintColor),
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
            Text('Reason for reporting', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.xs),
            ..._reasons.map((String r) {
              final bool isSelected = _selectedReason == r;
              return InkWell(
                onTap: () => setState(() => _selectedReason = r),
                borderRadius: AppRadius.smAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primary : theme.hintColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                ),
              ),
              child: TextField(
                controller: _detailsController,
                maxLines: 2,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                  border: InputBorder.none,
                ),
              ),
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
                    label: 'Submit Report',
                    loading: _submitting,
                    onPressed: _submitReport,
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
