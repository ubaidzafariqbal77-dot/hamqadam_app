import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_button.dart';

/// Modal dialog allowing the member to write a proposal note
/// and send a formal marriage proposal (`POST /proposals` with `user_id` and `note`).
class SendProposalDialog extends StatefulWidget {
  const SendProposalDialog({super.key, required this.profile});

  final SearchProfileModel profile;

  static Future<bool?> show(BuildContext context, SearchProfileModel profile) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SendProposalDialog(profile: profile),
    );
  }

  @override
  State<SendProposalDialog> createState() => _SendProposalDialogState();
}

class _SendProposalDialogState extends State<SendProposalDialog> {
  final ProposalController _proposalCtrl = Get.find<ProposalController>();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _quickNotes = <String>[
    'Assalam-o-Alaikum, I found your profile suitable and would like our families to connect.',
    'Assalam-o-Alaikum, interested in sending a formal proposal for marriage consideration.',
    'Assalam-o-Alaikum, I would like to express interest in moving forward with your rishta.',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSubmitting = true);
    final String note = _noteController.text.trim();

    final bool sent = await _proposalCtrl.sendProposal(
      widget.profile.id,
      note: note.isNotEmpty ? note : null,
      recipientName: widget.profile.displayName,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop(sent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: Title & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Send Proposal',
                      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Profile info preview tile
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: widget.profile.hasPhoto
                          ? Image.network(
                              widget.profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackAvatar(),
                            )
                          : _fallbackAvatar(),

                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.profile.displayName,
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.profile.code != null && widget.profile.code!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${widget.profile.code}',
                            style: TextStyle(fontSize: 11, color: theme.hintColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Note field
            Text(
              'Proposal Note (Optional)',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Add a message or formal introduction...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            // Quick Note chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickNotes.map((String note) {
                return ActionChip(
                  label: Text(
                    note,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: isDark ? AppColors.darkSurfaceAlt : Colors.grey.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  onPressed: () {
                    setState(() {
                      _noteController.text = note;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Send Proposal',
                    icon: Icons.send_rounded,
                    loading: _isSubmitting,
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          widget.profile.initial,
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
