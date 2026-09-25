import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../models/chat_model.dart';

/// The reaction palette.
///
/// One short, familiar set rather than a full emoji keyboard: the sheet opens
/// from a long-press in the middle of a conversation, so it has to be a single
/// glance and a single tap.
const List<String> kChatReactionEmojis = <String>[
  '❤️',
  '😂',
  '👍',
  '😮',
  '😢',
  '🙏',
];

/// The row of emojis shown after a long-press on a bubble.
///
/// Tapping an emoji calls [onPick]; tapping the emoji this member already used
/// (or the trailing "remove" control) calls [onClear] — the same toggle the
/// server performs, so the two stay in agreement.
class ChatReactionPicker extends StatelessWidget {
  const ChatReactionPicker({
    super.key,
    required this.onPick,
    this.mine,
    this.onClear,
  });

  final ValueChanged<String> onPick;

  /// The emoji this member already reacted with, if any.
  final String? mine;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.chatCardFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.chatCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...kChatReactionEmojis.map((String emoji) {
            final bool selected = mine == emoji;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onPick(emoji),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.roseSelectedFill
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }),
          if (mine != null && mine!.isNotEmpty && onClear != null) ...<Widget>[
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppColors.chatCardBorder,
            ),
            IconButton(
              tooltip: 'Remove reaction',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.chatPreviewInk,
            ),
          ],
        ],
      ),
    );
  }
}

/// The little pills drawn under a bubble once a message has reactions.
///
/// `mine` is painted filled so the member can see their own at a glance, and
/// tapping any pill toggles that emoji — the same call the picker makes.
class MessageReactionRow extends StatelessWidget {
  const MessageReactionRow({
    super.key,
    required this.reactions,
    required this.onTap,
    this.alignEnd = false,
  });

  final List<ChatReaction> reactions;
  final ValueChanged<ChatReaction> onTap;

  /// Pills sit under the bubble's own edge: right for my messages, left for
  /// theirs, exactly like the bubble alignment.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final List<ChatReaction> visible =
        reactions.where((ChatReaction r) => r.emoji.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: visible.map((ChatReaction reaction) {
            final String who = reaction.users.isEmpty
                ? ''
                : reaction.users.join(', ');
            return Tooltip(
              message: who.isEmpty
                  ? reaction.emoji
                  : '$who reacted ${reaction.emoji}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => onTap(reaction),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: reaction.mine
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.chatPillGradient,
                            )
                          : null,
                      color: reaction.mine ? null : AppColors.chatCardFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: reaction.mine
                            ? Colors.transparent
                            : AppColors.chatCardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        if (reaction.count > 1) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            '${reaction.count}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: reaction.mine
                                  ? AppColors.chatPillInk
                                  : AppColors.chatPreviewInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
