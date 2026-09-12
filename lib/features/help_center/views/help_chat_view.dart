import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/help_chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/help_chat_model.dart';

/// HamQadam Help Center — the conversation a logged-in member opens from the
/// drawer's Help button. One thread per member; support replies arrive here
/// in real time.
class HelpChatView extends StatefulWidget {
  const HelpChatView({super.key});

  static void open({BuildContext? context}) {
    Get.to<void>(() => const HelpChatView());
  }

  @override
  State<HelpChatView> createState() => _HelpChatViewState();
}

class _HelpChatViewState extends State<HelpChatView> {
  final HelpChatController _controller = Get.find<HelpChatController>();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.isViewOpen.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.openHelpChat();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMoreMessages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Leaving the screen stops the subscription and the poller.
    _controller.isViewOpen.value = false;
    _controller.closeHelpChat();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo != null) _controller.addAttachment(photo.path);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _attachmentOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                _attachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFFE93B77),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final XFile? photo = await _imagePicker
                        .pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (photo != null) _controller.addAttachment(photo.path);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'HamQadam Help Center',
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'We usually reply within a few hours',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[

          // Realtime state — reserved for a connecting hint if needed later.
          const SizedBox.shrink(),

          // Closed banner
          Obx(() {
            if (!_controller.isClosed) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.12),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.lock_outline_rounded, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This conversation has been closed by support. Start a new message to open another one.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Messages stream
          Expanded(
            child: Obx(() {
              final ApiStatus status = _controller.messagesStatus.value;
              final List<HelpChatMessage> list = _controller.messages;

              if (status == ApiStatus.loading && list.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors.brandGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.support_agent_rounded, size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Assalam-o-Alaikum!', style: AppTextStyles.headline.copyWith(fontSize: 20)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Describe your issue below and our support team will get back to you right here.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                itemCount: list.length + (_controller.isLoadingMore.value ? 1 : 0),
                itemBuilder: (BuildContext ctx, int index) {
                  if (index >= list.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    );
                  }

                  final HelpChatMessage msg = list[index];
                  return _HelpMessageBubble(
                    message: msg,
                    isMine: !msg.fromAdmin,
                    onRetry: () => _controller.retryMessage(msg),
                  );
                },
              );
            }),
          ),

          // Pending attachments bar
          Obx(() {
            final List<String> paths = _controller.pendingAttachments;
            if (paths.isEmpty) return const SizedBox.shrink();
            return Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: paths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (BuildContext ctx, int i) {
                  final String path = paths[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.file(
                          File(path),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (BuildContext c, Object e, StackTrace? s) => Container(
                            width: 60,
                            height: 60,
                            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                            child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary, size: 28),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: InkWell(
                          onTap: () => _controller.removeAttachment(path),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }),

          _buildComposer(context, isDark),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context, bool isDark) {
    return Obx(() {
      final bool disabled = _controller.isClosed;
      return Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          MediaQuery.of(context).padding.bottom + AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightDivider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!disabled)
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
                tooltip: 'Attach Photo',
                onPressed: _showAttachmentOptions,
              ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
                ),
                child: TextField(
                  controller: _controller.messageInputController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !disabled,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: disabled
                        ? 'Conversation closed'
                        : 'Describe your issue…',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (!disabled)
              Obx(() {
                final bool sending = _controller.isSending.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                    onPressed: sending ? null : _controller.sendMessage,
                  ),
                );
              }),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Single message bubble
// ---------------------------------------------------------------------------

class _HelpMessageBubble extends StatelessWidget {
  const _HelpMessageBubble({
    required this.message,
    required this.isMine,
    required this.onRetry,
  });

  final HelpChatMessage message;
  final bool isMine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final String timeStr = DateFormat('d MMM, h:mm a').format(message.createdAt);

    final Color bubbleBg = isMine
        ? AppColors.primary
        : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface);              return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: message.isFailed ? onRetry : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 3),
              bottomRight: Radius.circular(isMine ? 3 : 18),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Who is talking — support messages are labelled.
              if (!isMine)
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    'HamQadam Support',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),

              // Text
              if (message.message.isNotEmpty)
                Text(
                  message.message,
                  style: TextStyle(
                    color: isMine ? Colors.white : theme.textTheme.bodyLarge?.color,
                    fontSize: 14.5,
                  ),
                ),

              // Attachment previews
              if (message.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.attachments.map((ChatAttachment a) {
                      if (a.isImage) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            a.url,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext c, Object e, StackTrace? s) => Container(
                              width: 140,
                              height: 140,
                              color: Colors.black.withValues(alpha: 0.12),
                              child: Icon(Icons.image_outlined, color: isMine ? Colors.white : AppColors.primary),
                            ),
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.insert_drive_file_rounded, size: 18, color: isMine ? Colors.white : AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              a.originalName.isNotEmpty ? a.originalName : 'Attachment',
                              style: TextStyle(fontSize: 12, color: isMine ? Colors.white : null),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Local previews while uploading
              if ((message.isPending || message.isFailed) && message.localAttachmentPaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: message.localAttachmentPaths.map((String path) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Image.file(
                                File(path),
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext _, Object __, StackTrace? ___) => Container(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  child: Icon(Icons.image_outlined, color: isMine ? Colors.white : AppColors.primary),
                                ),
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: message.isFailed ? 0.35 : 0.18),
                              ),
                              Center(
                                child: message.isFailed
                                    ? const Icon(Icons.refresh_rounded, color: Colors.white, size: 26)
                                    : const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 3),

              // Time + delivery state
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Colors.white.withValues(alpha: 0.7) : theme.hintColor,
                    ),
                  ),
                  if (isMine) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(
                      message.isPending
                          ? Icons.schedule_rounded
                          : message.isFailed
                              ? Icons.error_outline_rounded
                              : Icons.done_all_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ],
                  if (isMine && message.isFailed) ...<Widget>[
                    const SizedBox(width: 4),
                    const Text(
                      'Tap to retry',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
