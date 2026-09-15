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

/// Community forums: forum list → thread list → thread posts (replies), with
/// thread creation and replying. Three push levels, one controller.
class ForumsView extends StatefulWidget {
  const ForumsView({super.key});

  @override
  State<ForumsView> createState() => _ForumsViewState();
}

class _ForumsViewState extends State<ForumsView> {
  final ContentController _controller = Get.find<ContentController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadForums());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: const PremiumAppBar(title: 'Community Forums', subtitle: 'Discuss, share and learn together'),
      body: Obx(() {
        final ApiState<ContentPage<Map<String, dynamic>>> state = _controller.forumsState.value;

        switch (state.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: _controller.loadForums);
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(message: state.message, onRetry: _controller.loadForums);
          case ApiStatus.empty:
            return const EmptyStateWidget(
              title: 'No forums yet',
              message: 'Community discussions will appear here once the forums open.',
            );
          case ApiStatus.success:
            final List<Map<String, dynamic>> items = state.data?.items ?? <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _controller.loadForums(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext ctx, int i) => _ForumCard(item: items[i]),
              ),
            );
        }
      }),
    );
  }
}

class _ForumCard extends StatelessWidget {
  const _ForumCard({required this.item});

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
    final ContentController controller = Get.find<ContentController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String title = _field(<String>['title', 'name']);
    final String desc = _field(<String>['description', 'summary', 'details']);
    final dynamic threads = item['threads_count'] ?? item['threads'] ?? item['total_threads'];

    return InkWell(
      borderRadius: AppRadius.lgAll,
      onTap: () {
        controller.loadForumThreads(item);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _ForumThreadsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (desc.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(desc, style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (threads != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$threads',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.lightTextHint),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level 2: threads inside a forum
// ---------------------------------------------------------------------------

class _ForumThreadsScreen extends StatefulWidget {
  const _ForumThreadsScreen();

  @override
  State<_ForumThreadsScreen> createState() => _ForumThreadsScreenState();
}

class _ForumThreadsScreenState extends State<_ForumThreadsScreen> {
  final ContentController _controller = Get.find<ContentController>();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, dynamic> forum = _controller.selectedForum.value ?? <String, dynamic>{};
    final String forumTitle = (forum['title'] ?? forum['name'] ?? 'Forum').toString();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: PremiumAppBar(title: forumTitle, subtitle: 'Discussions'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_thread_fab',
        backgroundColor: AppColors.primary,
        onPressed: _showNewThreadSheet,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
        label: const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        final ApiState<ContentPage<Map<String, dynamic>>> state = _controller.threadsState.value;

        switch (state.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(
                onRetry: () => _controller.loadForumThreads(_controller.selectedForum.value ?? <String, dynamic>{}));
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(
              message: state.message,
              onRetry: () => _controller.loadForumThreads(_controller.selectedForum.value ?? <String, dynamic>{}),
            );
          case ApiStatus.empty:
            return const EmptyStateWidget(
              title: 'No discussions yet',
              message: 'Start the first conversation in this forum.',
            );
          case ApiStatus.success:
            final List<Map<String, dynamic>> items = state.data?.items ?? <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _controller.loadForumThreads(_controller.selectedForum.value ?? <String, dynamic>{}),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext ctx, int i) {
                  final Map<String, dynamic> t = items[i];
                  final String title = (t['title'] ?? 'Discussion').toString();
                  final String body = (t['body'] ?? t['excerpt'] ?? '').toString();
                  final dynamic replies = t['posts_count'] ?? t['replies_count'];
                  final String author = (t['author'] is Map
                          ? (t['author'] as Map)['name']
                          : t['author_name'] ?? 'Member')
                      .toString();

                  return InkWell(
                    borderRadius: AppRadius.lgAll,
                    onTap: () {
                      _controller.loadThreadPosts(t);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const _ThreadPostsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5)),
                          if (body.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(body, style: AppTextStyles.caption.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.lightTextHint),
                              const SizedBox(width: 4),
                              Text(author, style: AppTextStyles.caption),
                              const Spacer(),
                              if (replies != null) ...<Widget>[
                                const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.lightTextHint),
                                const SizedBox(width: 4),
                                Text('$replies replies', style: AppTextStyles.caption),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
        }
      }),
    );
  }

  void _showNewThreadSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) => const _NewThreadSheet(),
    );
  }
}

class _NewThreadSheet extends StatefulWidget {
  const _NewThreadSheet();

  @override
  State<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends State<_NewThreadSheet> {
  final ContentController _controller = Get.find<ContentController>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().length < 5) {
      AppSnackbar.info('Give your discussion a clear title.');
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      AppSnackbar.info('Write a few words to start the discussion.');
      return;
    }
    final bool ok = await _controller.createThread(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Start a Discussion', style: AppTextStyles.title),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'What do you want to discuss?',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Your message',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                ),
                onPressed: _submit,
                child: const Text('Post Discussion',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level 3: posts (replies) inside a thread
// ---------------------------------------------------------------------------

class _ThreadPostsScreen extends StatefulWidget {
  const _ThreadPostsScreen();

  @override
  State<_ThreadPostsScreen> createState() => _ThreadPostsScreenState();
}

class _ThreadPostsScreenState extends State<_ThreadPostsScreen> {
  final ContentController _controller = Get.find<ContentController>();
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, dynamic> thread = _controller.selectedThread.value ?? <String, dynamic>{};
    final String threadTitle = (thread['title'] ?? 'Discussion').toString();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: PremiumAppBar(title: threadTitle, subtitle: 'Replies'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Obx(() {
              final ApiState<ContentPage<Map<String, dynamic>>> state = _controller.postsState.value;

              switch (state.status) {
                case ApiStatus.initial:
                case ApiStatus.loading:
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                case ApiStatus.noInternet:
                  return NoInternetWidget(
                      onRetry: () => _controller.loadThreadPosts(_controller.selectedThread.value ?? <String, dynamic>{}));
                case ApiStatus.unauthorized:
                case ApiStatus.serverError:
                case ApiStatus.validationError:
                  return ErrorStateWidget(
                    message: state.message,
                    onRetry: () => _controller.loadThreadPosts(_controller.selectedThread.value ?? <String, dynamic>{}),
                  );
                case ApiStatus.empty:
                  return const EmptyStateWidget(
                    title: 'No replies yet',
                    message: 'Be the first to share your thoughts.',
                  );
                case ApiStatus.success:
                  final List<Map<String, dynamic>> items = state.data?.items ?? <Map<String, dynamic>>[];
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => _controller.loadThreadPosts(_controller.selectedThread.value ?? <String, dynamic>{}),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext ctx, int i) {
                        final Map<String, dynamic> p = items[i];
                        final String body = (p['body'] ?? p['message'] ?? '').toString();
                        final String author = (p['author'] is Map
                                ? (p['author'] as Map)['name']
                                : p['author_name'] ?? 'Member')
                            .toString();
                        final bool isOp = i == 0;

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: AppRadius.lgAll,
                            border: isOp
                                ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
                                : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                    child: Text(
                                      author.isNotEmpty ? author[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(author, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                                  if (isOp) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text('OP',
                                          style: TextStyle(
                                              fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(body, style: AppTextStyles.body.copyWith(fontSize: 13.5, height: 1.45)),
                            ],
                          ),
                        );
                      },
                    ),
                  );
              }
            }),
          ),
          // Reply composer
          Container(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, MediaQuery.of(context).padding.bottom + AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightDivider)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a reply…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    final String text = _replyCtrl.text.trim();
                    if (text.isEmpty) return;
                    final bool ok = await _controller.replyToThread(body: text);
                    if (ok) _replyCtrl.clear();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.brandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
