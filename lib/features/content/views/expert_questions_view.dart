import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/content_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../repositories/content_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';

/// Expert Q&A: answered questions from the relationship experts, plus an
/// anonymous "Ask the expert" submission flow.
class ExpertQuestionsView extends StatefulWidget {
  const ExpertQuestionsView({super.key});

  @override
  State<ExpertQuestionsView> createState() => _ExpertQuestionsViewState();
}

class _ExpertQuestionsViewState extends State<ExpertQuestionsView> {
  final ContentController _controller = Get.find<ContentController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadExpertQuestions());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.roseCanvas,
      appBar: const PremiumAppBar(title: 'Expert Advice', subtitle: 'Questions answered by professionals'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ask_expert_fab',
        backgroundColor: AppColors.regAccent,
        onPressed: _showAskSheet,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
        label: const Text('Ask', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        final ApiState<ContentPage<Map<String, dynamic>>> state = _controller.expertState.value;

        switch (state.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.regAccent));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: _controller.loadExpertQuestions);
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(message: state.message, onRetry: _controller.loadExpertQuestions);
          case ApiStatus.empty:
            return const EmptyStateWidget(
              title: 'No answered questions yet',
              message: 'Be the first to ask — questions are answered by qualified relationship experts.',
            );
          case ApiStatus.success:
            final List<Map<String, dynamic>> items = state.data?.items ?? <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: AppColors.regAccent,
              onRefresh: () => _controller.loadExpertQuestions(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 90),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext ctx, int i) => _QuestionCard(item: items[i]),
              ),
            );
        }
      }),
    );
  }

  void _showAskSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) => const _AskExpertSheet(),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item});

  final Map<String, dynamic> item;

  String _field(List<String> keys) {
    for (final String k in keys) {
      final dynamic v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String question = _field(<String>['question', 'title']);
    final String answer = _field(<String>['answer', 'reply', 'response', 'details']);
    final String category = _field(<String>['category', 'topic']);
    final String askedBy = _field(<String>['asked_by', 'user_name', 'name']);
    final bool anonymous = item['is_anonymous'] == true || askedBy.isEmpty || askedBy == 'null';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (category.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.regAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(category,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.regAccent)),
                ),
              const Spacer(),
              Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
              const SizedBox(width: 4),
              Text('Answered', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.help_outline_rounded, size: 17, color: AppColors.regAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5)),
              ),
            ],
          ),
          if (answer.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightSurfaceAlt.withValues(alpha: 0.7),
                borderRadius: AppRadius.mdAll,
                border: Border(left: BorderSide(color: AppColors.regAccent, width: 3)),
              ),
              child: Text(answer, style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.45)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            anonymous ? 'Asked anonymously' : 'Asked by $askedBy',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _AskExpertSheet extends StatefulWidget {
  const _AskExpertSheet();

  @override
  State<_AskExpertSheet> createState() => _AskExpertSheetState();
}

class _AskExpertSheetState extends State<_AskExpertSheet> {
  final ContentController _controller = Get.find<ContentController>();
  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _detailsCtrl = TextEditingController();
  String _category = 'General';
  bool _anonymous = true;

  static const List<String> _categories = <String>[
    'General', 'Family', 'Marriage', 'Relationship', 'Religious', 'Health', 'Other',
  ];

  @override
  void dispose() {
    _questionCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_questionCtrl.text.trim().length < 10) {
      AppSnackbar.info('Please write your question (at least 10 characters).');
      return;
    }
    final bool ok = await _controller.submitQuestion(
      category: _category,
      question: _questionCtrl.text.trim(),
      details: _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
      anonymous: _anonymous,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Ask the Expert', style: AppTextStyles.title),
              const SizedBox(height: 6),
              Text(
                'Your question is reviewed by qualified relationship experts. Answers appear publicly (anonymously if you prefer).',
                style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
                items: _categories
                    .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(),
                onChanged: (String? v) => setState(() => _category = v ?? 'General'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Your question',
                  hintText: 'e.g. How do I involve my family respectfully?',
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'More context (optional)',
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _anonymous,
                activeColor: AppColors.regAccent,
                title: const Text('Ask anonymously', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                onChanged: (bool v) => setState(() => _anonymous = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.regAccent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  onPressed: _submit,
                  child: const Text('Send Question',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
