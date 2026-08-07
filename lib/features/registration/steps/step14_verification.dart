import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/utils/cnic_ocr_service.dart';
import '../../../core/utils/media_picker_helper.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/media_upload_card.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 14 — Identity verification. CNIC front/back and the selfie are captured
/// from the camera, one after another (like step 1): the back card is only
/// revealed once the front is captured, and the selfie once the back is done.
/// The CNIC number is auto-read from BOTH the front and the back with on-device
/// OCR and the two are compared to confirm the same card was photographed.
/// Documents are held in the buffer (memory only) and uploaded on the
/// Finalizing screen.
class Step14Controller extends StepController {
  Step14Controller() : super(14);

  MediaPickerHelper get picker => Get.find<MediaPickerHelper>();
  final CnicOcrService _ocr = CnicOcrService();

  final Rxn<PickedMedia> front = Rxn<PickedMedia>();
  final Rxn<PickedMedia> cnicBack = Rxn<PickedMedia>();
  final Rxn<PickedMedia> selfie = Rxn<PickedMedia>();

  /// CNIC number read from the FRONT image (the one we keep/submit).
  final RxString cnicNumber = ''.obs;

  /// CNIC number read from the BACK image (used only to compare with the front).
  final RxString cnicBackNumber = ''.obs;

  final RxBool scanning = false.obs; // scanning the front
  final RxBool scanningBack = false.obs; // scanning the back

  /// null  = not compared yet (a number is still missing from one side),
  /// true  = front & back numbers match,
  /// false = the two sides carry different numbers.
  final Rxn<bool> backMatches = Rxn<bool>();

  Future<void> pickFront() async {
    final PickedMedia? m = await _capture();
    if (m == null) return;
    front.value = m;
    await _scanFront(m.path);
  }

  Future<void> pickBack() async {
    final PickedMedia? m = await _capture();
    if (m == null) return;
    cnicBack.value = m;
    await _scanBack(m.path);
  }

  Future<void> pickSelfie() async {
    final PickedMedia? m = await _capture();
    if (m != null) selfie.value = m;
  }

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

  Future<PickedMedia?> _capture() async {
    final PickedMedia? m = await picker.pickImage(fromCamera: true);
    if (m == null) return null;
    final MediaValidation v = MediaPickerHelper.validateImage(m);
    if (!v.isValid) {
      AppSnackbar.error(v.error!);
      return null;
    }
    return m;
  }

  Future<void> _scanFront(String path) async {
    scanning.value = true;
    try {
      final String? cnic = await _ocr.extractCnic(path);
      if (cnic != null) {
        cnicNumber.value = cnic;
        AppSnackbar.success('CNIC number detected: $cnic');
      } else {
        cnicNumber.value = '';
        AppSnackbar.info('Could not read the CNIC number — please retake a clear photo.');
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
    if (cnicNumber.value.trim().isEmpty) {
      error.value = 'CNIC number could not be read — retake a clearer front photo.';
      return false;
    }
    // The back must carry the SAME number as the front before continuing.
    // A mismatch (false) or an unreadable back (null) both block the step so
    // the user re-uploads a proper, clear back image of the same card.
    if (backMatches.value != true) {
      error.value = backMatches.value == false
          ? 'The CNIC number on the back does not match the front. Please '
              'upload the back of the SAME card.'
          : 'Couldn\'t read the CNIC number on the back. Please upload a '
              'clear back image so it can be matched with the front.';
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
      helpText: 'Capture your CNIC front, then the back, then a selfie. Your '
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
              ] else if (c.cnicNumber.value.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                FormFieldContainer(
                  label: 'CNIC number (auto-detected)',
                  requirement: FieldRequirement.required,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(c.cnicNumber.value, style: AppTextStyles.bodyStrong),
                  ),
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
        message = 'Couldn\'t read the number on the back — upload a clearer '
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
