import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../core/utils/media_picker_helper.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';

/// Upload tile with preview, pick and remove for a single media item.
class MediaUploadCard extends StatelessWidget {
  const MediaUploadCard({
    super.key,
    required this.label,
    required this.media,
    required this.onPick,
    required this.onRemove,
    this.requirement = FieldRequirement.optional,
    this.icon = Icons.add_photo_alternate_rounded,
    this.isImage = true,
    this.height = 150,
  });

  final String label;
  final PickedMedia? media;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final FieldRequirement requirement;
  final IconData icon;
  final bool isImage;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = media != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label: label, requirement: requirement),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: FieldStyle.background(context, requirement),
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: FieldStyle.border(context, requirement), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasMedia
                ? Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (isImage)
                        Image.file(File(media!.path), fit: BoxFit.cover)
                      else
                        _FileBadge(media: media!, icon: icon),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onRemove,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(icon, size: 34, color: AppColors.primary),
                      const SizedBox(height: 6),
                      BiText(
                        'Tap to upload',
                        textAlign: TextAlign.center,
                        gap: 0,
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _FileBadge extends StatelessWidget {
  const _FileBadge({required this.media, required this.icon});
  final PickedMedia media;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 34, color: AppColors.primary),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              media.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ),
          Text(
            '${(media.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}
