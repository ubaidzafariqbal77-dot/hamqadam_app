import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../controllers/call_controller.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../widgets/chat_report_dialog.dart';



/// Full-screen active conversation screen with real-time stream.
class ChatConversationView extends StatefulWidget {
  const ChatConversationView({super.key, required this.thread});

  final ChatThread thread;

  static void open(ChatThread thread, {BuildContext? context}) {
    Get.to<void>(() => ChatConversationView(thread: thread));
  }

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  final ChatController _controller = Get.find<ChatController>();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.openThread(widget.thread);
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo != null) {
      _controller.addAttachment(photo.path);
    }
  }

  Future<void> _pickDocument() async {
    final PlatformFile? file = await FilePicker.pickFile();
    if (file != null && file.path != null) {
      _controller.addAttachment(file.path!);
    }
  }

  /// Fallback thumbnail for non-image pending attachments.
  Widget _pendingDocThumb(bool isDark) {
    return Container(
      width: 60,
      height: 60,
      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
      child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary, size: 28),
    );
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
                    final XFile? photo =
                        await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (photo != null) _controller.addAttachment(photo.path);
                  },
                ),
                _attachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  color: const Color(0xFF1644A6),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocument();
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

    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) _controller.closeThread();
      },
      child: Scaffold(
        appBar: _buildAppBar(context, isDark),
        body: Column(
          children: <Widget>[
            // Blocked notice
            Obx(() {
              final ChatThread? t = _controller.activeThread.value;
              if (t?.isBlocked != true) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                color: AppColors.error.withValues(alpha: 0.12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.block_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This conversation is blocked.',
                        style: TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _controller.toggleBlock,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Unblock', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),

            // Messages Stream
            Expanded(
              child: Obx(() {
                final ApiStatus status = _controller.messagesStatus.value;
                final List<ChatMessage> list = _controller.messages;

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
                          Icon(Icons.mark_chat_read_outlined, size: 48, color: theme.hintColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No messages yet', style: AppTextStyles.bodyStrong),
                          const SizedBox(height: 4),
                          Text(
                            'Say Assalam-o-Alaikum to start the conversation!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(color: theme.hintColor),
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

                    final ChatMessage msg = list[index];
                    final bool isMine = msg.isMine(_controller.myUserId);

                    return _MessageBubble(
                      message: msg,
                      isMine: isMine,
                      participantName: widget.thread.participant.name,
                      participantPhoto: widget.thread.participant.photo,
                      onReply: () => _controller.setReplyTo(msg),
                      onDelete: () => _controller.deleteMessageForMe(msg.id),
                    );

                  },
                );
              }),
            ),

            // Typing indicator bubble
            Obx(() {
              if (!_controller.isOtherTyping.value) return const SizedBox.shrink();
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Typing', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Reply Quote Preview Bar
            Obx(() {
              final ChatMessage? replyMsg = _controller.replyingTo.value;
              if (replyMsg == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                child: Row(
                  children: <Widget>[
                    Container(width: 3, height: 32, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            replyMsg.isMine(_controller.myUserId) ? 'Replying to yourself' : 'Replying to ${widget.thread.participant.name}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            replyMsg.message.isNotEmpty ? replyMsg.message : '📎 Attachment',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _controller.cancelReply,
                    ),
                  ],
                ),
              );
            }),

            // Pending Attachments Bar
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
                    final String ext = path.split('.').last.toLowerCase();
                    final bool isImg = <String>[
                      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
                    ].contains(ext);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: isImg
                              ? Image.file(
                                  File(path),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                                      _pendingDocThumb(isDark),
                                )
                              : _pendingDocThumb(isDark),
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


            // Message Composer Input Box
            _buildComposer(context, isDark),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 1,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () {
          _controller.closeThread();
          Navigator.of(context).pop();
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: widget.thread.participant.hasPhoto
                ? NetworkImage(widget.thread.participant.photo!)
                : null,
            child: !widget.thread.participant.hasPhoto
                ? Text(
                    widget.thread.participant.initial,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.thread.participant.name,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Obx(() {
                  final bool typing = _controller.isOtherTyping.value;
                  return Text(
                    typing ? 'Typing…' : (widget.thread.participant.isOnline ? 'Online' : 'Active'),
                    style: TextStyle(
                      fontSize: 11,
                      color: typing
                          ? AppColors.primary
                          : (widget.thread.participant.isOnline ? AppColors.success : Theme.of(context).hintColor),
                      fontWeight: typing || widget.thread.participant.isOnline ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
          tooltip: 'Voice Call',
          onPressed: () => _startCall(isVideo: false),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 24),
          tooltip: 'Video Call',
          onPressed: () => _startCall(isVideo: true),
        ),

        PopupMenuButton<String>(

          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          onSelected: (String value) {
            switch (value) {
              case 'block':
                _controller.toggleBlock();
                break;
              case 'clear':
                _confirmClear();
                break;
              case 'report':
                ChatReportDialog.show(context, widget.thread);
                break;
            }
          },
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'block',
              child: Obx(() {
                final bool isBlocked = _controller.activeThread.value?.isBlocked == true;
                return Row(
                  children: <Widget>[
                    Icon(isBlocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(isBlocked ? 'Unblock Chat' : 'Block Chat'),
                  ],
                );
              }),
            ),
            const PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: <Widget>[
                  Icon(Icons.delete_sweep_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Clear History'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: <Widget>[
                  Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Report Chat', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComposer(BuildContext context, bool isDark) {
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
          // Attachment Button
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
            tooltip: 'Attach Media or Document',
            onPressed: _showAttachmentOptions,
          ),
          // Text Input Box
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
                onChanged: _controller.onTextChanged,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
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
          // Send Button
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
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear this chat history from your device?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.clearHistory();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Unified call initiation — checks if already in a call, uses consistent
  /// channel naming, and passes the real caller name.
  /// Starts a call through the backend (`POST /calls`), the same way the
  /// website does. The server creates the call row, mints this member's Agora
  /// token and rings the other side over `call-incoming`; the controller opens
  /// the call screen once it has the credentials.
  void _startCall({required bool isVideo}) {
    if (!Get.isRegistered<CallController>()) {
      AppSnackbar.error('Calling is unavailable right now.');
      return;
    }
    Get.find<CallController>().startCall(
      threadId: widget.thread.id,
      isVideo: isVideo,
    );
  }
}

// ---------------------------------------------------------------------------
// Single Message Bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onReply,
    required this.onDelete,
    this.participantName,
    this.participantPhoto,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final String? participantName;
  final String? participantPhoto;


  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
            if (message.message.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.message));
                  Navigator.pop(ctx);
                  AppSnackbar.info('Message copied.');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete for me', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final String timeStr = DateFormat('h:mm a').format(message.createdAt);

    // Separate images from documents
    final List<ChatAttachment> images =
        message.attachments.where((ChatAttachment a) => a.isImage).toList();
    final List<ChatAttachment> docs =
        message.attachments.where((ChatAttachment a) => !a.isImage).toList();

    // Bubble bg
    final Color bubbleBg = isMine
        ? AppColors.primary
        : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface);

    // For image-only messages, use zero padding + rounded clipping
    final bool hasOnlyImages = images.isNotEmpty && docs.isEmpty && message.message.isEmpty;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
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
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 3),
              bottomRight: Radius.circular(isMine ? 3 : 18),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Images grid (WhatsApp style) ──────────────────────────
                if (images.isNotEmpty)

                  Stack(
                    children: <Widget>[
                      _ImageGrid(images: images),
                      if (hasOnlyImages)
                        Positioned(
                          bottom: 6,
                          right: isMine ? 6 : null,
                          left: isMine ? null : 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isMine) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                // ── Text + docs + time ────────────────────────────────────
                if (!hasOnlyImages)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment:
                          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: <Widget>[
                        // Quoted reply preview
                        if (message.replyToMessage != null) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border(
                                left: BorderSide(
                                  color: isMine ? Colors.white70 : AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              message.replyToMessage!.message.isNotEmpty
                                  ? message.replyToMessage!.message
                                  : '📎 Attachment',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMine ? Colors.white70 : theme.hintColor,
                              ),
                            ),
                          ),
                        ],

                        // Document cards
                        ...docs.map((ChatAttachment a) =>
                            _DocCard(attachment: a, isMine: isMine, theme: theme)),

                        // Message text / Call event tile
                        if (message.isCallEvent)
                          InkWell(
                            // A call tile is a record of a past call, so tapping
                            // it calls back rather than rejoining: the channel it
                            // names belonged to that call and the server has long
                            // since closed it.
                            onTap: () {
                              if (!message.isCallInvite) return;
                              if (!Get.isRegistered<CallController>()) return;
                              Get.find<CallController>().startCall(
                                threadId: message.threadId,
                                isVideo: message.isCallVideo,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    message.isCallVideo
                                        ? Icons.videocam_rounded
                                        : Icons.call_rounded,
                                    size: 20,
                                    color: isMine ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    message.callDisplayName,
                                    style: TextStyle(
                                      color: isMine
                                          ? Colors.white
                                          : theme.textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (message.message.isNotEmpty)
                          Text(
                            message.message,
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color,
                              fontSize: 14.5,
                            ),
                          ),

                        const SizedBox(height: 3),
                        // Time + tick row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : theme.hintColor,
                              ),
                            ),
                            if (isMine) ...<Widget>[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// Image Grid (WhatsApp-style): 1 image = full width, 2+ = grid
// ---------------------------------------------------------------------------

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});
  final List<ChatAttachment> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return _ChatImage(url: images.first.url);
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < images.length; i += 2)
          Row(
            children: <Widget>[
              Expanded(child: _ChatImage(url: images[i].url, height: 130)),
              if (i + 1 < images.length)
                Expanded(child: _ChatImage(url: images[i + 1].url, height: 130)),
            ],
          ),
      ],
    );
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.url, this.height});
  final String url;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext ctx, Widget child, ImageChunkEvent? progress) {
          if (progress == null) return child;
          return SizedBox(
            height: height ?? 180,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (BuildContext ctx, Object e, StackTrace? st) => Container(
          height: height ?? 180,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImage(url: url),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document Card (WhatsApp-style)
// ---------------------------------------------------------------------------

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.attachment,
    required this.isMine,
    required this.theme,
  });

  final ChatAttachment attachment;
  final bool isMine;
  final ThemeData theme;

  static const Map<String, IconData> _extIcons = <String, IconData>{
    'pdf': Icons.picture_as_pdf_rounded,
    'doc': Icons.description_rounded,
    'docx': Icons.description_rounded,
    'xls': Icons.table_chart_rounded,
    'xlsx': Icons.table_chart_rounded,
    'ppt': Icons.co_present_rounded,
    'pptx': Icons.co_present_rounded,
    'zip': Icons.folder_zip_rounded,
    'rar': Icons.folder_zip_rounded,
    'mp3': Icons.audio_file_rounded,
    'mp4': Icons.video_file_rounded,
  };

  static const Map<String, Color> _extColors = <String, Color>{
    'pdf': Color(0xFFE53935),
    'doc': Color(0xFF1565C0),
    'docx': Color(0xFF1565C0),
    'xls': Color(0xFF2E7D32),
    'xlsx': Color(0xFF2E7D32),
    'ppt': Color(0xFFBF360C),
    'pptx': Color(0xFFBF360C),
    'zip': Color(0xFFF57F17),
    'rar': Color(0xFFF57F17),
    'mp3': Color(0xFF6A1B9A),
    'mp4': Color(0xFF00838F),
  };

  String get _ext {
    final String name = attachment.originalName.isNotEmpty
        ? attachment.originalName
        : attachment.name;
    return name.split('.').last.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon = _extIcons[_ext] ?? Icons.insert_drive_file_rounded;
    final Color iconColor = _extColors[_ext] ?? AppColors.primary;
    final String fileName =
        attachment.originalName.isNotEmpty ? attachment.originalName : attachment.name;

    return GestureDetector(
      onTap: () => _openDoc(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.black.withValues(alpha: 0.18)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // File type icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            // File name + ext badge
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ext.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.65)
                          : iconColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download icon
            Icon(
              Icons.download_rounded,
              size: 18,
              color: isMine ? Colors.white70 : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDoc(BuildContext context) async {
    final String downloadUrl = attachment.downloadUrl.isNotEmpty
        ? attachment.downloadUrl
        : attachment.url;
    if (downloadUrl.isNotEmpty) {
      // Just show a snack — real launch needs url_launcher
      AppSnackbar.info('Opening: $downloadUrl');
    }
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer
// ---------------------------------------------------------------------------

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (BuildContext ctx, Object e, StackTrace? st) =>
                const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 80),
          ),
        ),
      ),
    );
  }
}

