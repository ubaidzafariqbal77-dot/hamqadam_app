import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/utils/media_picker_helper.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/step_scaffold.dart';

class Step12Controller extends StepController {
  Step12Controller() : super(12);

  MediaPickerHelper get picker => Get.find<MediaPickerHelper>();

  final Rxn<PickedMedia> profile = Rxn<PickedMedia>();
  final RxList<PickedMedia> gallery = <PickedMedia>[].obs;

  static const int maxAdditional = 4;

  int get photoCount => (profile.value == null ? 0 : 1) + gallery.length;

  Future<void> pickMain() async {
    final PickedMedia? m = await _pick();
    if (m != null) profile.value = m;
  }

  Future<void> addGallery() async {
    if (gallery.length >= maxAdditional) return;
    final PickedMedia? m = await _pick();
    if (m != null) gallery.add(m);
  }

  Future<PickedMedia?> _pick() async {
    final PickedMedia? m = await picker.pickImage();
    if (m == null) return null;
    final MediaValidation v = MediaPickerHelper.validateImage(m);
    if (!v.isValid) {
      AppSnackbar.error(v.error!);
      return null;
    }
    return m;
  }

  @override
  bool extraValidate() {
    if (photoCount < 3) {
      error.value = 'Please add at least 3 photos (1 main + 2 more).';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'profile_photo': profile.value?.path,
    'gallery': gallery.map((PickedMedia e) => e.path).toList(),
  };
}

class Step12View extends StatefulWidget {
  const Step12View({super.key});
  @override
  State<Step12View> createState() => _Step12ViewState();
}

class _Step12ViewState extends State<Step12View> {
  late final Step12Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step12Controller());
  }

  @override
  void dispose() {
    Get.delete<Step12Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 12,
      totalSteps: 18,
      title: 'Upload photos',
      subtitle: 'You need to upload at least 3 photos to continue. '
          'You can change them later.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Add photos',
      onPrimary: c.submit,
      onBack: c.back,
      helpText: 'Use clear, recent photos of yourself. Avoid group photos for '
          'your main picture.',
      children: <Widget>[
        Obx(
          () => GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.82,
            children: <Widget>[
              _PhotoCell(
                media: c.profile.value,
                isMain: true,
                onTap: c.pickMain,
                onRemove: () => c.profile.value = null,
              ),
              for (int i = 0; i < Step12Controller.maxAdditional; i++)
                if (i < c.gallery.length)
                  _PhotoCell(
                    media: c.gallery[i],
                    onTap: () {},
                    onRemove: () => c.gallery.removeAt(i),
                  )
                else if (i == c.gallery.length)
                  _PhotoCell(media: null, onTap: c.addGallery, onRemove: () {})
                else
                  const _PhotoCell(media: null, disabled: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.media,
    this.onTap,
    this.onRemove,
    this.isMain = false,
    this.disabled = false,
  });

  final PickedMedia? media;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool isMain;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = media != null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Stack(
          children: <Widget>[
            DottedContainer(hasMedia: hasMedia, child: hasMedia ? Image.file(File(media!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.add_rounded, size: 30, color: AppColors.primary))),
            if (isMain)
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasMedia ? Colors.black87 : AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                  child: BiText(
                    'Main',
                    textAlign: TextAlign.center,
                    gap: 0,
                    style: AppTextStyles.caption.copyWith(color: Colors.white),
                    urduColor: Colors.white,
                  ),
                ),
              ),
            if (hasMedia && onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DottedContainer extends StatelessWidget {
  const DottedContainer({super.key, required this.child, this.hasMedia = false});
  final Widget child;
  final bool hasMedia;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hasMedia ? null : Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: hasMedia ? Colors.transparent : Theme.of(context).dividerColor,
          width: 1.4,
        ),
      ),
      child: child,
    );
  }
}
