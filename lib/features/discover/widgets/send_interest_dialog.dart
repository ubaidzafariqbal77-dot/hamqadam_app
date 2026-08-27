import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';

/// Modal dialog allowing the member to write an optional `initial_note`
/// and send an express interest proposal (`POST /interests` with `user_id` and `initial_note`).
class SendInterestDialog extends StatefulWidget {
  const SendInterestDialog({super.key, required this.profile});

  final SearchProfileModel profile;

  static Future<bool?> show(BuildContext context, SearchProfileModel profile) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SendInterestDialog(profile: profile),
    );
  }

  @override
  State<SendInterestDialog> createState() => _SendInterestDialogState();
}

class _SendInterestDialogState extends State<SendInterestDialog> {
  final InterestController _interestCtrl = Get.find<InterestController>();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _quickNotes = <String>[
    'Assalam-o-Alaikum, I found your profile suitable and would like to connect.',
    'Assalam-o-Alaikum, interested in taking things forward with family involvement.',
    'Hello, looking forward to getting to know more about you.',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSubmitting = true);
    final String note = _noteController.text.trim();

    // Call POST /interests with user_id and optional initial_note
    final SendInterestOutcome outcome = await _interestCtrl.sendInterest(
      widget.profile.id,
      note: note.isNotEmpty ? note : null,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop(outcome.sent);
    }

    if (outcome.sent) {
      AppSnackbar.success(outcome.message);
    } else {
      AppSnackbar.error(outcome.message);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header with close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: widget.profile.hasPhoto
                          ? NetworkImage(widget.profile.photoUrl!)
                          : null,
                      child: !widget.profile.hasPhoto
                          ? Text(
                              widget.profile.initial,
                              style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Express Interest',
                          style: AppTextStyles.title.copyWith(fontSize: 18),
                        ),
                        Text(
                          'Send connection request to ${widget.profile.displayName}',
                          style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.lightDivider),
              const SizedBox(height: AppSpacing.md),

              // Note label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Initial Note', style: AppTextStyles.bodyStrong),
                  Text(
                    'Optional',
                    style: AppTextStyles.caption.copyWith(color: AppColors.optionalBadge),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Text field for initial_note
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                  ),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 4,
                  maxLength: 300,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Add a personalized message (optional)...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Quick template chips
              Text(
                'Quick Suggestions',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickNotes.map((String note) {
                  return ActionChip(
                    label: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: const TextStyle(fontSize: 11, color: AppColors.primary),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _noteController.text = note;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
                      label: 'Send Interest',
                      icon: Icons.favorite_rounded,
                      loading: _isSubmitting,
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
