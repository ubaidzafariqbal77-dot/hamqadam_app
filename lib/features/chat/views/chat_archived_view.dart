import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import 'chat_conversation_view.dart';
import 'chat_inbox_view.dart';

/// The member's archived conversations.
///
/// A plain list on the same blush canvas as the inbox, reusing its cards and
/// dotted separators so an archived chat looks like the chat it was — the only
/// difference being that opening it, or long-pressing it, offers "Move back to
/// inbox". The list comes from `GET /chat/threads?archived=1`, so it reflects
/// the member's own archive state and nobody else's.
class ChatArchivedView extends StatelessWidget {
  const ChatArchivedView({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    // Entering the screen is the moment the list is worth fetching; the inbox
    // deliberately does not pay for it on every load.
    controller.loadArchivedThreads();

    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Archived',
        subtitle: 'Chats you set aside',
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.chatCanvasTop,
              AppColors.chatCanvasBottom,
            ],
          ),
        ),
        child: Obx(() {
          final ApiState<List<ChatThread>> state =
              controller.archivedThreadsState.value;

          switch (state.status) {
            case ApiStatus.initial:
            case ApiStatus.loading:
              return const SkeletonList();
            case ApiStatus.noInternet:
              return NoInternetWidget(onRetry: controller.loadArchivedThreads);
            case ApiStatus.unauthorized:
            case ApiStatus.serverError:
            case ApiStatus.validationError:
              return ErrorStateWidget(
                message: state.message,
                onRetry: controller.loadArchivedThreads,
              );
            case ApiStatus.empty:
              return const _NothingArchived();
            case ApiStatus.success:
              final List<ChatThread> list = state.data ?? <ChatThread>[];
              if (list.isEmpty) return const _NothingArchived();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: controller.loadArchivedThreads,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xxxl,
                  ),
                  itemCount: list.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final ChatThread thread = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: <Widget>[
                          ChatThreadCard(
                            thread: thread,
                            onTap: () => ChatConversationView.open(thread),
                            onLongPress: () =>
                                showChatThreadActions(ctx, thread),
                          ),
                          if (i < list.length - 1)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: ChatDottedDivider(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
          }
        }),
      ),
    );
  }
}

class _NothingArchived extends StatelessWidget {
  const _NothingArchived();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppColors.chatTimeInk,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing archived',
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                color: AppColors.roseTitleInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Long-press a conversation in your inbox to tuck it away here. '
              'Archiving only affects your own list.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.chatPreviewInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
