import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/utils/cnic_ocr_service.dart';
import '../../../core/utils/media_picker_helper.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/media_upload_card.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 14 — Identity verification. CNIC front/back and the selfie can each be
/// shot with the camera or picked from the gallery, one after another (like
/// step 1): the back card is only revealed once the front is captured, and the
/// selfie once the back is done.
/// On-device OCR pre-fills the CNIC number from the front and cross-checks the
/// back, but the number stays editable: a card OCR cannot read must not
/// dead-end signup. Only a positive front/back MISMATCH blocks the step.
/// Documents are held in the buffer (memory only) and submitted with the rest
/// of the payload from the Finalizing screen.
class Step14Controller extends StepController {
  Step14Controller() : super(14);

  MediaPickerHelper get picker => Get.find<MediaPickerHelper>();
  final CnicOcrService _ocr = CnicOcrService();

  final Rxn<PickedMedia> front = Rxn<PickedMedia>();
  final Rxn<PickedMedia> cnicBack = Rxn<PickedMedia>();
  final Rxn<PickedMedia> selfie = Rxn<PickedMedia>();

  /// CNIC number for the FRONT image (the one we keep/submit). Pre-filled by
  /// OCR and editable — OCR assists, it does not gate the step.
  final RxString cnicNumber = ''.obs;

  /// Backing controller for the editable CNIC field.
  final TextEditingController cnicCtrl = TextEditingController();

  /// True once OCR filled the field, so the label can say so.
  final RxBool cnicAutoRead = false.obs;

  void onCnicTyped(String raw) {
    final String formatted = CnicOcrService.format(raw);
    if (formatted != raw) {
      cnicCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    cnicAutoRead.value = false;
    cnicNumber.value = formatted;
    _compareBack();
  }

  /// CNIC number read from the BACK image (used only to compare with the front).
  final RxString cnicBackNumber = ''.obs;

  final RxBool scanning = false.obs; // scanning the front
  final RxBool scanningBack = false.obs; // scanning the back

  /// null  = not compared yet (a number is still missing from one side),
  /// true  = front & back numbers match,
  /// false = the two sides carry different numbers.
  final Rxn<bool> backMatches = Rxn<bool>();

  Future<void> pickFront() async {
    final PickedMedia? m = await _capture(highRes: true);
    if (m == null) return;
    front.value = m;
    await _scanFront(m.path);
  }

  Future<void> pickBack() async {
    final PickedMedia? m = await _capture(highRes: true);
    if (m == null) return;
    cnicBack.value = m;
    await _scanBack(m.path);
  }

  Future<void> pickSelfie() async {
    final PickedMedia? m = await _capture();
    if (m != null) selfie.value = m;
  }

  @override
  void disposeFields() => cnicCtrl.dispose();

  void removeFront() {
    front.value = null;
    cnicNumber.value = '';
    _compareBack();
  }

  void removeBack() {
    cnicBack.value = null;
    cnicBackNumber.value = '';
    backMatches.value = null;
  }

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

  Future<void> _scanFront(String path) async {
    scanning.value = true;
    try {
      final String? cnic = await _ocr.extractCnic(path);
      if (cnic != null) {
        cnicNumber.value = cnic;
        cnicCtrl.text = cnic;
        cnicAutoRead.value = true;
        AppSnackbar.success('CNIC number detected: $cnic');
      } else if (cnicNumber.value.trim().isEmpty) {
        // Never wipe a number the user typed themselves.
        cnicAutoRead.value = false;
        AppSnackbar.info('Could not read the number — please type it below.');
      }
      // A re-taken front may change the number, so re-check any existing back.
      _compareBack();
    } finally {
      scanning.value = false;
    }
  }

  Future<void> _scanBack(String path) async {
    scanningBack.value = true;
    try {
      final String? cnic = await _ocr.extractCnic(path);
      cnicBackNumber.value = cnic ?? '';
      _compareBack();
      if (backMatches.value == true) {
        AppSnackbar.success('CNIC back matches the front.');
      } else if (backMatches.value == false) {
        AppSnackbar.error('The number on the back does not match the front.');
      }
    } finally {
      scanningBack.value = false;
    }
  }

  /// Compares the front and back numbers when both are available.
  void _compareBack() {
    final String f = cnicNumber.value.trim();
    final String bk = cnicBackNumber.value.trim();
    backMatches.value = (f.isEmpty || bk.isEmpty) ? null : (f == bk);
  }

  @override
  bool extraValidate() {
    if (front.value == null || cnicBack.value == null || selfie.value == null) {
      error.value = 'Please capture the CNIC front, back and a selfie.';
      return false;
    }
    if (!CnicOcrService.isValid(cnicNumber.value)) {
      error.value = 'Enter the 13-digit CNIC number as XXXXX-XXXXXXX-X.';
      return false;
    }
    // Only a POSITIVE mismatch blocks: both sides were read and they disagree,
    // which means two different cards. An unreadable back does not block —
    // the number is confirmed by the (editable) field above, and many cards do
    // not print it on the back at all.
    if (backMatches.value == false) {
      error.value =
          'The CNIC number on the back does not match the front. '
          'Please upload the back of the SAME card.';
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
          'Capture your CNIC front, then the back, then a selfie. Your '
          'CNIC number is read automatically and both sides are matched.',
      children: <Widget>[
        // 1 — CNIC FRONT + its auto-read number (always visible).
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MediaUploadCard(
                label: 'CNIC front',
                media: c.front.value,
                icon: Icons.badge_rounded,
                onPick: c.pickFront,
                onRemove: c.removeFront,
              ),
              if (c.scanning.value) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const _ScanningRow(label: 'Reading CNIC number…'),
              ] else if (c.front.value != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                // Editable: OCR pre-fills it when it can, but a card it cannot
                // read must never dead-end the flow.
                AppTextFormField(
                  label: c.cnicAutoRead.value
                      ? 'CNIC number (auto-detected — check it)'
                      : 'CNIC number',
                  controller: c.cnicCtrl,
                  hint: 'XXXXX-XXXXXXX-X',
                  keyboardType: TextInputType.number,
                  onChanged: c.onCnicTyped,
                  validator: (String? v) => CnicOcrService.isValid(v ?? '')
                      ? null
                      : 'Enter the 13-digit number as XXXXX-XXXXXXX-X',
                ),
              ],
            ],
          ),
        ),

        // 2 — CNIC BACK, revealed only once the front is captured.
        Obx(
          () => c.front.value == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    MediaUploadCard(
                      label: 'CNIC back',
                      media: c.cnicBack.value,
                      icon: Icons.badge_outlined,
                      onPick: c.pickBack,
                      onRemove: c.removeBack,
                    ),
                    if (c.scanningBack.value) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      const _ScanningRow(label: 'Matching with the front…'),
                    ] else if (c.cnicBack.value != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _MatchBanner(state: c.backMatches.value),
                    ],
                  ],
                ),
        ),

        // 3 — SELFIE, revealed only once the back is captured.
        Obx(
          () => c.cnicBack.value == null
              ? const SizedBox.shrink()
              : MediaUploadCard(
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

/// A small spinner + bilingual caption shown while OCR runs.
class _ScanningRow extends StatelessWidget {
  const _ScanningRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: BiText(label, gap: 0, style: AppTextStyles.caption)),
      ],
    );
  }
}

/// Result of comparing the front and back CNIC numbers.
class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.state});

  /// true = match, false = mismatch, null = couldn't compare (back unreadable).
  final bool? state;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String message;
    switch (state) {
      case true:
        color = AppColors.success;
        icon = Icons.verified_rounded;
        message = 'Verified — the back matches the front CNIC number.';
        break;
      case false:
        color = AppColors.error;
        icon = Icons.error_outline_rounded;
        message = 'The number on the back does not match the front.';
        break;
      default:
        color = AppColors.warning;
        icon = Icons.info_outline_rounded;
        message =
            'Couldn\'t read the number on the back — upload a clearer '
            'back image of the same card to continue.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: BiText(
              message,
              gap: 0,
              style: AppTextStyles.caption.copyWith(color: color),
              urduColor: color,
            ),
          ),
        ],
      ),
    );
  }
}
