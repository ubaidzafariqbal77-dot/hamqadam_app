import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'form_field_container.dart';

/// A segmented 6-box OTP input. Backed by a single hidden [TextField] (so
/// backspace, paste and IME all behave correctly) with the digits rendered as
/// individual boxes on top.
class AppOtpField extends StatefulWidget {
  const AppOtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.label,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final String? label;
  final ValueChanged<String>? onCompleted;

  @override
  State<AppOtpField> createState() => _AppOtpFieldState();
}

class _AppOtpFieldState extends State<AppOtpField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == widget.length) {
      widget.onCompleted?.call(widget.controller.text);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null)
          FieldLabel(label: widget.label!, requirement: FieldRequirement.required),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).requestFocus(_focus),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Real (transparent) input — captures keyboard/backspace/paste.
              SizedBox(
                height: 58,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent, height: 0.1),
                  cursorColor: Colors.transparent,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(widget.length, (int i) {
                    final bool filled = i < text.length;
                    final bool active =
                        _focus.hasFocus && (i == text.length || (i == widget.length - 1 && filled));
                    return _OtpBox(
                      char: filled ? text[i] : '',
                      active: active,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.char, required this.active});
  final String char;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color border = active
        ? AppColors.primary
        : (dark ? AppColors.darkBorder : AppColors.lightBorder);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: border, width: active ? 1.8 : 1.2),
      ),
      child: Text(
        char,
        style: AppTextStyles.headline.copyWith(
          color: dark ? AppColors.darkInputText : AppColors.lightInputText,
        ),
      ),
    );
  }
}
