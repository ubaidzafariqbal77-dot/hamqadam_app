import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../widgets/app_snackbar.dart';

/// "Export chat" — the backup half of the chat feature.
///
/// The server hands back one JSON document for the whole conversation
/// (`GET /chat/threads/{thread}/export`: peer, every message still visible with
/// its attachments and reactions). This sheet fetches it, writes it to the
/// app's documents directory so it survives a reinstall-free copy-out, and
/// offers the same JSON on the clipboard.
///
/// Nothing is bundled or cached beforehand — if the conversation changes, the
/// next export reflects it, because the file is built from that one response.
class ChatExportSheet extends StatefulWidget {
  const ChatExportSheet({super.key});

  /// Opens the sheet over the current conversation.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.chatCanvasTop,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      builder: (BuildContext _) => const ChatExportSheet(),
    );
  }

  @override
  State<ChatExportSheet> createState() => _ChatExportSheetState();
}

class _ChatExportSheetState extends State<ChatExportSheet> {
  String? _filePath;
  String? _error;
  int _messageCount = 0;
  String _peerName = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ChatController controller = Get.find<ChatController>();
    _peerName = controller.activeThread.value?.participant.name ?? 'Chat';

    final Map<String, dynamic>? payload = await controller.fetchChatExport();
    if (!mounted) return;

    if (payload == null) {
      setState(() => _error = 'Could not build the export. Please try again.');
      return;
    }

    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final String safeName = _peerName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final File file =
          File('${dir.path}/chat_${safeName.isEmpty ? 'export' : safeName}_$stamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      if (!mounted) return;
      setState(() {
        _filePath = file.path;
        _messageCount = payload['message_count'] as int? ??
            ((payload['messages'] as List<dynamic>?) ?? <dynamic>[]).length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not write the backup file: $e');
    }
  }

  Future<void> _copy() async {
    final ChatController controller = Get.find<ChatController>();
    final Map<String, dynamic>? payload = await controller.fetchChatExport();
    if (payload == null) {
      AppSnackbar.error('Could not build the export.');
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(payload),
      ),
    );
    AppSnackbar.success('Chat backup copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Export chat',
              style: AppTextStyles.displaySerif.copyWith(
                fontSize: 22,
                color: AppColors.roseTitleInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _peerName.isEmpty
                  ? 'A JSON backup of this conversation'
                  : 'A JSON backup of your conversation with $_peerName',
              style: AppTextStyles.body
                  .copyWith(fontSize: 13.5, color: AppColors.chatPreviewInk),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              _Status(
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                title: 'Export failed',
                detail: _error!,
              )
            else if (_filePath == null)
              const _Status(
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.primary,
                title: 'Building your backup…',
                detail: 'Downloading every message in this conversation.',
                loading: true,
              )
            else ...<Widget>[
              _Status(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                title: 'Backup saved',
                detail: '$_messageCount messages saved to the app’s documents '
                    'folder.',
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.chatCardBorder),
                ),
                child: Text(
                  _filePath!,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: AppColors.chatPreviewInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    label: const Text('Copy JSON'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.chatCardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.loading = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          height: 22,
          child: loading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.bodyStrong
                    .copyWith(fontSize: 14, color: AppColors.roseTitleInk),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTextStyles.body
                    .copyWith(fontSize: 12.5, color: AppColors.chatPreviewInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
