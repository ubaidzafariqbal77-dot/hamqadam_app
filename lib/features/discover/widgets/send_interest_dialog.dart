import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../models/message_template_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/message_template_repository.dart';
import '../../proposals/widgets/message_template_picker.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';

/// Send Interest: a simple static action (spec §1). The member picks one of
/// the admin-managed messages, previews it and confirms; the joined text goes
/// out as `initial_note` on `POST /interests`.
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
  bool _isSubmitting = false;

  /// Admin-managed library (spec §12); null while loading.
  List<MessageTemplate>? _templates;
  MessageTemplate? _selected;

  /// Super Like / Priority Interest toggle. Only offered when the member's plan
  /// grants `priority_interest`; the price comes back from the server.
  bool _superLike = false;

  @override
  void initState() {
    super.initState();
    Get.find<MessageTemplateRepository>()
        .fetch(MessageTemplateType.interest)
        .then((List<MessageTemplate> list) {
      if (!mounted) return;
      setState(() {
        _templates = list;
        _selected = list.isNotEmpty ? list.first : null;
      });
    });
  }

  Future<void> _send() async {
    final MessageTemplate? template = _selected;
    if (template == null) {
      AppSnackbar.info('Please choose a message first.');
      return;
    }
    final String note = template.fullText;
    final int? templateId = int.tryParse(template.id);
    if (templateId == null) {
      AppSnackbar.error('Messages are unavailable right now. Please try again in a moment.');
      return;
    }
    final bool confirmed = await confirmMessageSend(
      context,
      title: _superLike ? 'Send Super Like?' : 'Send Interest?',
      recipientName: widget.profile.displayName,
      message: note,
      confirmLabel: 'Send',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);

    // Call POST /interests with user_id, optional initial_note and priority
    final SendInterestOutcome outcome = await _interestCtrl.sendInterest(
      widget.profile.id,
      templateId: templateId,
      priority: _superLike,
    );

    if (!mounted) return;
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

              // Super Like — only offered when the plan entitles it.
              Obx(() {
                final bool entitled = _interestCtrl.hasPriorityInterest;
                if (!entitled) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _superLike = !_superLike),
                    borderRadius: AppRadius.mdAll,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        gradient: _superLike
                            ? const LinearGradient(colors: AppColors.brandGradient)
                            : null,
                        color: _superLike
                            ? null
                            : (isDark
                                ? AppColors.darkSurfaceAlt
                                : AppColors.lightSurface),
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(
                          color: _superLike
                              ? Colors.transparent
                              : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.star_rounded,
                            size: 22,
                            color: _superLike
                                ? Colors.white
                                : AppColors.optionalBadge,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Super Like',
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    color: _superLike
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.roseTitleInk),
                                  ),
                                ),
                                Text(
                                  'Priority interest — stands out to '
                                  '${widget.profile.displayName}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: _superLike
                                        ? Colors.white70
                                        : theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _superLike,
                            onChanged: _isSubmitting
                                ? null
                                : (bool v) => setState(() => _superLike = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              Text('Choose a message', style: AppTextStyles.bodyStrong),
              const SizedBox(height: 2),
              Text(
                'Tap a message to preview it in full.',
                style: AppTextStyles.caption.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_templates == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                MessageTemplatePicker(
                  templates: _templates!,
                  selectedId: _selected?.id,
                  onSelected: (MessageTemplate t) => setState(() => _selected = t),
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
                      label: _superLike ? 'Send Super Like' : 'Send Interest',
                      icon: _superLike
                          ? Icons.star_rounded
                          : Icons.favorite_rounded,
                      loading: _isSubmitting,
                      onPressed: _selected == null ? null : _send,
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
