import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../constants/reg_icons.dart';
import '../../../core/validators/app_validators.dart';
import '../../../repositories/bio_ai_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/step_scaffold.dart';
import '../bio_ai_profile.dart';

/// Screen 13 — About yourself, the API's step 12
/// (`POST /auth/register/step/12` → `{about_me}`, max 2500 characters).
class Step13Controller extends StepController {
  Step13Controller() : super(13);

  static const int maxChars = 2500;

  final TextEditingController aboutMe = TextEditingController();

  /// Kept for the whole registration, so every tap rotates the templates.
  BioAiRepository get _ai => Get.isRegistered<BioAiRepository>()
      ? Get.find<BioAiRepository>()
      : Get.put(BioAiRepository(), permanent: true);

  final RxBool generating = false.obs;

  /// Writes a bio from the answers to the earlier steps: opening template +
  /// AI middle + closing template, sized by the requirements' 90-150 word
  /// rules (well inside [maxChars]).
  Future<void> generateWithAi() async {
    if (generating.value) return;
    generating.value = true;
    error.value = '';
    try {
      final Map<String, dynamic> profile = await BioAiProfile.build(
        buffer,
        Get.find<LookupController>(),
      );
      final BioAiResult result = await _ai.generate(
        profile,
        maxChars: maxChars,
      );
      aboutMe.text = result.text.length > maxChars
          ? result.text.substring(0, maxChars)
          : result.text;
      aboutMe.selection = TextSelection.collapsed(offset: aboutMe.text.length);
    } on BioAiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error(
        'Could not generate a bio right now. Please try again.',
      );
    } finally {
      generating.value = false;
    }
  }

  @override
  void restore() => aboutMe.text = buffer.getString('about_me') ?? '';

  /// First visit with an empty box: draft a bio straight away, so the member
  /// only has to accept it or tap Regenerate. Runs once per registration —
  /// after that an empty box is the member's own choice.
  void autoDraftOnce() {
    const String flag = '__about_me_ai_drafted';
    if (aboutMe.text.trim().isNotEmpty || buffer.getString(flag) == '1') return;
    buffer.putOne(flag, '1');
    generateWithAi();
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'about_me': aboutMe.text.trim(),
  };

  @override
  void disposeFields() => aboutMe.dispose();
}

class Step13View extends StatefulWidget {
  const Step13View({super.key});
  @override
  State<Step13View> createState() => _Step13ViewState();
}

class _Step13ViewState extends State<Step13View> {
  late final Step13Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step13Controller());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.autoDraftOnce();
    });
  }

  @override
  void dispose() {
    Get.delete<Step13Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 13,
      totalSteps: 18,
      title: 'About yourself',
      art: RegIcons.step13About,
      artIcon: Icons.favorite_outline_rounded,
      subtitle: 'We drafted an introduction for you. Keep it, edit it, or regenerate it with AI.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        AppTextFormField(
          insetLabel: true,
          label: 'About yourself',
          controller: c.aboutMe,
          hint: 'Tell potential matches a little about who you are…',
          maxLines: 16,
          minLines: 12,
          maxLength: Step13Controller.maxChars,
          showCounter: true,
          textInputAction: TextInputAction.newline,
          validator: (String? v) {
            final String? req = AppValidators.required(
              v,
              field: 'About yourself',
            );
            if (req != null) return req;
            return AppValidators.minLength(v, 20, field: 'About yourself');
          },
        ),
        // Under the box, right-aligned: inside it, the button covered text.
        Align(
          alignment: Alignment.centerRight,
          child: _AiButton(controller: c),
        ),
      ],
    );
  }
}

/// "AI" pill that fills the field with a generated bio; tap again for another.
class _AiButton extends StatelessWidget {
  const _AiButton({required this.controller});

  final Step13Controller controller;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Obx(() {
      final bool busy = controller.generating.value;
      return Tooltip(
        message: 'Write my bio with AI',
        child: Material(
          color: accent,
          shape: const StadiumBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: busy ? null : controller.generateWithAi,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (busy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    busy
                        ? 'Writing…'
                        : (controller.aboutMe.text.trim().isEmpty
                            ? 'Write with AI'
                            : 'Regenerate with AI'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
