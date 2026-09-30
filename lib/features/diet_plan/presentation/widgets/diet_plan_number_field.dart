import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Labelled numeric input — Figma `input/text` with the label 6dp above.
class DietPlanNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;
  final bool decimal;
  final TextStyle? labelStyle;

  const DietPlanNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffix,
    this.decimal = false,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle ?? context.text.titleSmall),
        const SizedBox(height: AppDimens.inputLabelGap),
        TextField(
          controller: controller,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixStyle: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ),
      ],
    );
  }
}
