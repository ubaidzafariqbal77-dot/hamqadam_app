import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../models/message_template_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/message_template_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../discover/widgets/send_interest_dialog.dart';
import 'message_template_picker.dart';

/// Send Proposal — the serious marriage-intention step (spec §2 Stage 3).
///
/// Only available once an interest between the pair is accepted; before that
/// [show] opens the "Send Interest First" popup instead (spec §3). The member
/// starts from an editable static template or an AI draft, and nothing is sent
/// without the final preview being confirmed — AI never sends on its own.
class SendProposalDialog extends StatefulWidget {
  const SendProposalDialog({super.key, required this.profile});

  final SearchProfileModel profile;

  static Future<bool?> show(BuildContext context, SearchProfileModel profile) async {
    final ProposalController proposalCtrl = Get.find<ProposalController>();
    if (proposalCtrl.hasSentProposalTo(profile.id)) {
      AppSnackbar.info('You have already sent a proposal to ${profile.displayName}.');
      return false;
    }

    final InterestController interestCtrl = Get.find<InterestController>();
    final bool accepted = await interestCtrl.ensureInterestAccepted(profile.id);
    if (!context.mounted) return false;

    if (!accepted) {
      final bool sendInterest = await _showLockedPopup(context);
      if (sendInterest && context.mounted) {
        await SendInterestDialog.show(context, profile);
      }
      return false;
    }

    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SendProposalDialog(profile: profile),
    );
  }

  /// Exact copy from spec §3. Cancel changes nothing.
  static Future<bool> _showLockedPopup(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        icon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
        title: Text('Send Interest First', style: AppTextStyles.title),
        content: Text(
          'Before sending a proposal, you need to express your interest in this profile.\n\n'
          'Send an interest request first. Once your interest is accepted, you can send a '
          'personalized marriage proposal.',
          style: AppTextStyles.body.copyWith(height: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Send Interest')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  State<SendProposalDialog> createState() => _SendProposalDialogState();
}

enum _ComposeMode { template, ai }

class _SendProposalDialogState extends State<SendProposalDialog> {
  final ProposalController _proposalCtrl = Get.find<ProposalController>();
  final MessageTemplateRepository _templateRepo = Get.find<MessageTemplateRepository>();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _intentionsController = TextEditingController();

  _ComposeMode _mode = _ComposeMode.template;
  List<MessageTemplate>? _templates;
  MessageTemplate? _selected;

  /// English and Urdu today; the server takes any language code, so more can
  /// be added here without touching the flow (spec §5).
  static const Map<String, String> _languages = <String, String>{'en': 'English', 'ur': 'اردو'};
  String _language = 'en';
  bool _familyIntro = true;
  bool _generating = false;
  int _generation = 0;
  bool _isSubmitting = false;

  /// True once the text in the box came from the AI draft (until a template is picked).
  bool _aiUsed = false;

  @override
  void initState() {
    super.initState();
    _templateRepo.fetch(MessageTemplateType.proposal).then((List<MessageTemplate> list) {
      if (!mounted) return;
      setState(() => _templates = list);
      if (list.isNotEmpty) _pickTemplate(list.first);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _intentionsController.dispose();
    super.dispose();
  }

  void _pickTemplate(MessageTemplate t) {
    setState(() {
      _selected = t;
      _aiUsed = false;
      _messageController.text = t.fullText;
    });
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final String text = await _templateRepo.generateProposal(
        receiverId: widget.profile.id,
        language: _language,
        includeFamilyIntro: _familyIntro,
        intentions: _intentionsController.text,
        generation: ++_generation,
      );
      if (!mounted) return;
      if (text.isEmpty) throw const FormatException('empty');
      setState(() {
        _aiUsed = true;
        _messageController.text = text;
      });
    } catch (e) {
      if (!mounted) return;
      // Static templates stay the fallback whenever AI is unavailable (spec §5).
      AppSnackbar.error(
        e is AppException && e.message.isNotEmpty
            ? e.message
            : 'AI is unavailable right now. Please choose a template instead.',
      );
      setState(() => _mode = _ComposeMode.template);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _send() async {
    final String note = _messageController.text.trim();
    if (note.isEmpty) {
      AppSnackbar.info('Please write or choose a proposal message first.');
      return;
    }
    if (note.length < 20) {
      AppSnackbar.info('Your proposal message should be at least 20 characters.');
      return;
    }
    final bool confirmed = await confirmMessageSend(
      context,
      title: 'Send Proposal?',
      recipientName: widget.profile.displayName,
      message: note,
      confirmLabel: 'Send Proposal',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    final bool sent = await _proposalCtrl.sendProposal(
      widget.profile.id,
      message: note,
      language: _language,
      fromAi: _aiUsed,
      templateId: int.tryParse(_selected?.id ?? ''),
      recipientName: widget.profile.displayName,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (sent) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool hasText = _messageController.text.trim().isNotEmpty;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Send Proposal', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        'To ${widget.profile.displayName}',
                        style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ComposeMode>(
                segments: const <ButtonSegment<_ComposeMode>>[
                  ButtonSegment<_ComposeMode>(
                    value: _ComposeMode.template,
                    icon: Icon(Icons.article_outlined, size: 18),
                    label: Text('Templates'),
                  ),
                  ButtonSegment<_ComposeMode>(
                    value: _ComposeMode.ai,
                    icon: Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text('Write with AI'),
                  ),
                ],
                selected: <_ComposeMode>{_mode},
                onSelectionChanged: (Set<_ComposeMode> s) => setState(() => _mode = s.first),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_mode == _ComposeMode.template) ..._templateControls(theme) else ..._aiControls(theme),

            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Your proposal', style: AppTextStyles.bodyStrong),
                Text('Editable', style: AppTextStyles.caption.copyWith(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              minLines: 5,
              maxLines: 10,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.body.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: _mode == _ComposeMode.ai
                    ? 'Tap Generate to draft your proposal…'
                    : 'Choose a template above, then edit it as you like…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
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
                    label: 'Preview & Send',
                    icon: Icons.visibility_outlined,
                    loading: _isSubmitting,
                    onPressed: hasText && !_generating ? _send : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _templateControls(ThemeData theme) {
    final List<MessageTemplate>? list = _templates;
    if (list == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (list.isEmpty) {
      return const <Widget>[MessageTemplatePicker(templates: <MessageTemplate>[], selectedId: null, onSelected: _noop)];
    }
    return <Widget>[
      Text('Choose a template', style: AppTextStyles.bodyStrong),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list.map((MessageTemplate t) {
          return ChoiceChip(
            label: Text(t.title, style: const TextStyle(fontSize: 12)),
            selected: _selected?.id == t.id,
            onSelected: (_) => _pickTemplate(t),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _aiControls(ThemeData theme) {
    return <Widget>[
      Text('Language', style: AppTextStyles.bodyStrong),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: _languages.entries.map((MapEntry<String, String> e) {
          return ChoiceChip(
            label: Text(e.value),
            selected: _language == e.key,
            onSelected: (_) => setState(() => _language = e.key),
          );
        }).toList(),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _familyIntro,
        onChanged: (bool v) => setState(() => _familyIntro = v),
        title: Text('Include a family introduction', style: AppTextStyles.body),
      ),
      TextField(
        controller: _intentionsController,
        maxLines: 3,
        maxLength: 400,
        decoration: InputDecoration(
          labelText: 'Your intentions (optional)',
          hintText: 'In your own words — AI only uses what you write here and public profile details.',
          hintMaxLines: 2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_generation == 0 ? Icons.auto_awesome_rounded : Icons.refresh_rounded, size: 18),
          label: Text(_generation == 0 ? 'Generate' : 'Regenerate'),
        ),
      ),
    ];
  }

  static void _noop(MessageTemplate _) {}
}
