import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/utils/cnic_format.dart';
import '../../../core/utils/media_picker_helper.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/media_upload_card.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 14 — Identity verification. The member uploads the CNIC front, the CNIC
/// back and a selfie — each either shot with the camera or picked from the
/// gallery — and types the CNIC number themselves.
///
/// There is no OCR and no front/back cross-check. Both were removed: on-device
/// text recognition misread enough cards to be a nuisance, and its plugin has
/// no arm64-simulator slice, which made every iOS Simulator build depend on a
/// no-op stub. The only rule left is that the number is well-formed and all
/// three images are present — the real identity check is the AI pre-screen and
/// manual review on the server.
///
/// Documents are held in the buffer (memory only) and submitted with the rest
/// of the payload from the Finalizing screen.
class Step14Controller extends StepController {
  Step14Controller() : super(14);

  MediaPickerHelper get picker => Get.find<MediaPickerHelper>();

  final Rxn<PickedMedia> front = Rxn<PickedMedia>();
  final Rxn<PickedMedia> cnicBack = Rxn<PickedMedia>();
  final Rxn<PickedMedia> selfie = Rxn<PickedMedia>();

  /// The CNIC number, typed by the member.
  final RxString cnicNumber = ''.obs;

  /// Backing controller for the CNIC field.
  final TextEditingController cnicCtrl = TextEditingController();

  /// Reformats to `XXXXX-XXXXXXX-X` as the member types, keeping the caret at
  /// the end so the inserted dashes do not fight the keyboard.
  void onCnicTyped(String raw) {
    final String formatted = CnicFormat.format(raw);
    if (formatted != raw) {
      cnicCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    cnicNumber.value = formatted;
  }

  Future<void> pickFront() async {
    final PickedMedia? m = await _capture(highRes: true);
    if (m == null) return;
    front.value = m;
  }

  Future<void> pickBack() async {
    final PickedMedia? m = await _capture(highRes: true);
    if (m == null) return;
    cnicBack.value = m;
  }

  Future<void> pickSelfie() async {
    final PickedMedia? m = await _capture();
    if (m != null) selfie.value = m;
  }

  @override
  void disposeFields() => cnicCtrl.dispose();

  /// Removing the photo leaves the typed number alone — it is the member's own
  /// input, not something derived from the image.
  void removeFront() => front.value = null;

  void removeBack() => cnicBack.value = null;

  /// Asks whether to shoot the document now or pick an existing photo, then
  /// returns the validated image. Returns null if the user backs out.
  Future<PickedMedia?> _capture({bool highRes = false}) async {
    final bool? fromCamera = await _askSource();
    if (fromCamera == null) return null;
    final PickedMedia? m =
        await picker.pickImage(fromCamera: fromCamera, highRes: highRes);
    if (m == null) return null;
    final MediaValidation v = MediaPickerHelper.validateImage(m);
    if (!v.isValid) {
      AppSnackbar.error(v.error!);
      return null;
    }
    return m;
  }

  /// true = camera, false = gallery, null = dismissed.
  Future<bool?> _askSource() => Get.bottomSheet<bool>(
    SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: AppRadius.lgAll,
        ),
        // ListTile needs a Material ancestor or Flutter warns that its
        // background and ink splashes may be invisible.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: BiText('Add photo', style: AppTextStyles.subtitle),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: Text('Take a photo', style: AppTextStyles.body),
                onTap: () => Get.back<bool>(result: true),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: Text('Choose from gallery', style: AppTextStyles.body),
                onTap: () => Get.back<bool>(result: false),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );

  @override
  bool extraValidate() {
    if (front.value == null || cnicBack.value == null || selfie.value == null) {
      error.value = 'Please capture the CNIC front, back and a selfie.';
      return false;
    }
    if (!CnicFormat.isValid(cnicNumber.value)) {
      error.value = 'Enter the 13-digit CNIC number as XXXXX-XXXXXXX-X.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'cnic_number': cnicNumber.value.trim(),
    'cnic_front': front.value?.path,
    'cnic_back': cnicBack.value?.path,
    'selfie': selfie.value?.path,
  };
}

class Step14View extends StatefulWidget {
  const Step14View({super.key});
  @override
  State<Step14View> createState() => _Step14ViewState();
}

class _Step14ViewState extends State<Step14View> {
  late final Step14Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step14Controller());
  }

  @override
  void dispose() {
    Get.delete<Step14Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 14,
      totalSteps: 18,
      title: 'Identity verification',
      subtitle: 'Verify your identity to earn a trusted badge.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      helpText:
          'Upload your CNIC front, the CNIC back and a selfie, and type your '
          'CNIC number. Our team verifies them after you submit.',
      children: <Widget>[
        // 1 — CNIC number, typed by the member. Always visible: it no longer
        // depends on a photo having been read.
        AppTextFormField(
          label: 'CNIC number',
          controller: c.cnicCtrl,
          hint: 'XXXXX-XXXXXXX-X',
          keyboardType: TextInputType.number,
          onChanged: c.onCnicTyped,
          validator: (String? v) => CnicFormat.isValid(v ?? '')
              ? null
              : 'Enter the 13-digit number as XXXXX-XXXXXXX-X',
        ),

        // 2 — CNIC FRONT.
        Obx(
          () => MediaUploadCard(
            label: 'CNIC front',
            media: c.front.value,
            icon: Icons.badge_rounded,
            onPick: c.pickFront,
            onRemove: c.removeFront,
          ),
        ),

        // 3 — CNIC BACK.
        Obx(
          () => MediaUploadCard(
            label: 'CNIC back',
            media: c.cnicBack.value,
            icon: Icons.badge_outlined,
            onPick: c.pickBack,
            onRemove: c.removeBack,
          ),
        ),

        // 4 — SELFIE. No longer gated behind the other two: the member can add
        // the three images in whatever order suits them.
        Obx(
          () => MediaUploadCard(
            label: 'Selfie',
            media: c.selfie.value,
            icon: Icons.face_rounded,
            onPick: c.pickSelfie,
            onRemove: () => c.selfie.value = null,
          ),
        ),
      ],
    );
  }
}
