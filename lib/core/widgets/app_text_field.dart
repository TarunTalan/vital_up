import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';

/// Figma `input/text` box — glass fill, 20 radius, background blur and the
/// default / active / filled / error / success states. Shared by
/// [AppTextField] and the auth fields so every input looks the same.
class AppInputBox extends StatelessWidget {
  final Widget child;
  final bool focused;
  final bool filled;
  final bool hasError;
  final bool success;
  final bool enabled;
  final bool multiline;

  const AppInputBox({
    super.key,
    required this.child,
    this.focused = false,
    this.filled = false,
    this.hasError = false,
    this.success = false,
    this.enabled = true,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    // A disabled box never shows focus, success or the filled tint.
    final focused = this.focused && enabled;

    final Color fill;
    final Color border;
    final double borderWidth;
    if (!enabled) {
      fill = v.glassFill!;
      border = v.glassBorder!;
      borderWidth = AppDimens.borderThin;
    } else if (hasError) {
      fill = v.errorFill!;
      border = colors.error;
      borderWidth = AppDimens.borderThick;
    } else if (success) {
      fill = v.primaryFill!;
      border = v.success!;
      borderWidth = AppDimens.borderThick;
    } else if (focused) {
      fill = v.glassFill!;
      border = colors.primary;
      borderWidth = AppDimens.borderThick;
    } else if (filled) {
      fill = v.primaryFill!;
      border = v.glassBorder!;
      borderWidth = AppDimens.borderThin;
    } else {
      fill = v.glassFill!;
      border = v.glassBorder!;
      borderWidth = AppDimens.borderThin;
    }

    final radius = BorderRadius.circular(AppDimens.radiusInput);
    return AnimatedContainer(
      duration: AppDurations.medium,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: focused && !hasError ? AppShadows.inputFocus : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.glassBlur,
            sigmaY: AppDimens.glassBlur,
          ),
          child: AnimatedContainer(
            duration: AppDurations.medium,
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: AppTheme.responsiveInputHeight(context),
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(color: border, width: borderWidth),
            ),
            padding: EdgeInsetsDirectional.only(
              start: AppDimens.space16,
              end: AppDimens.space4,
              top: multiline ? AppDimens.space16 : 0,
              bottom: multiline ? AppDimens.space16 : 0,
            ),
            child: AnimatedOpacity(
              duration: AppDurations.medium,
              opacity: enabled ? 1 : AppDimens.disabledOpacity,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's standard text input: label above, [AppInputBox] field, and an
/// error line below. Works standalone (pass [error]) or inside a [Form]
/// (pass [validator]; `Form.validate()` shows its message).
class AppTextField extends StatefulWidget {
  final TextEditingController controller;

  /// Optional external focus node (e.g. from an Autocomplete).
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? error;
  final String? Function(String value)? validator;

  /// Unit shown after the value, e.g. "kcal".
  final String? suffixText;
  final Widget? suffix;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool multiline;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool showCounter;

  /// Keeps space for the error line so the layout doesn't jump.
  final bool reserveErrorSpace;

  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.error,
    this.validator,
    this.suffixText,
    this.suffix,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.multiline = false,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.showCounter = false,
    this.reserveErrorSpace = false,
  });

  /// Whole numbers only.
  const AppTextField.integer({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.error,
    this.validator,
    this.suffixText,
    this.suffix,
    this.prefixIcon,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.reserveErrorSpace = false,
  }) : keyboardType = TextInputType.number,
       inputFormatters = const [_digitsOnly],
       textCapitalization = TextCapitalization.none,
       onTap = null,
       readOnly = false,
       multiline = false,
       minLines = null,
       maxLines = 1,
       maxLength = null,
       showCounter = false;

  /// Numbers with an optional decimal part.
  const AppTextField.decimal({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.error,
    this.validator,
    this.suffixText,
    this.suffix,
    this.prefixIcon,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.reserveErrorSpace = false,
  }) : keyboardType = const TextInputType.numberWithOptions(decimal: true),
       inputFormatters = const [_decimalOnly],
       textCapitalization = TextCapitalization.none,
       onTap = null,
       readOnly = false,
       multiline = false,
       minLines = null,
       maxLines = 1,
       maxLength = null,
       showCounter = false;

  static const _digitsOnly = _RegexFormatter(r'^\d*$');
  static const _decimalOnly = _RegexFormatter(r'^\d*\.?\d*$');

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(AppTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  // Filled vs empty changes the box fill.
  void _onText() => setState(() {});

  Widget _field(String? errorText) {
    final colors = context.colors;
    final v = context.vColors;
    final hasError = errorText != null && errorText.isNotEmpty;
    final textColor = !widget.enabled
        ? v.grayText
        : hasError
        ? colors.error
        : _focused
        ? AppColors.primaryActive
        : colors.onSurface;
    final iconColor = hasError
        ? colors.error
        : _focused
        ? colors.primary
        : v.grayText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null || (widget.showCounter && widget.maxLength != null)) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.label != null)
                Text(
                  widget.label!,
                  style: context.text.titleSmall?.copyWith(color: colors.onSurface),
                )
              else
                const SizedBox.shrink(),
              if (widget.showCounter && widget.maxLength != null)
                Text(
                  '${widget.controller.text.length}/${widget.maxLength}',
                  style: context.text.bodySmall?.copyWith(color: v.grayText),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.inputLabelGap),
        ],
        AppInputBox(
          focused: _focused,
          filled: widget.controller.text.isNotEmpty,
          hasError: hasError,
          enabled: widget.enabled,
          multiline: widget.multiline,
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(
                  widget.prefixIcon,
                  size: AppDimens.iconMd,
                  color: iconColor,
                ),
                const SizedBox(width: AppDimens.space12),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  autofocus: widget.autofocus,
                  maxLength: widget.maxLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  keyboardType: widget.multiline
                      ? TextInputType.multiline
                      : widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  minLines: widget.multiline ? (widget.minLines ?? 1) : 1,
                  maxLines: widget.multiline ? widget.maxLines : 1,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onTap: widget.onTap,
                  onTapOutside: (_) {},
                  cursorColor: hasError ? colors.error : colors.primary,
                  style: context.text.bodyMedium?.copyWith(color: textColor),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: context.text.bodyMedium?.copyWith(
                      color: hasError ? colors.error : v.grayText,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.suffixText != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimens.space8,
                    end: AppDimens.space12,
                  ),
                  child: Text(
                    widget.suffixText!,
                    style: context.text.bodyMedium?.copyWith(color: v.grayText),
                  ),
                ),
              if (widget.suffix != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimens.space8,
                  ),
                  child: widget.suffix,
                ),
              if (widget.suffixText == null && widget.suffix == null)
                const SizedBox(width: AppDimens.space12),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: hasError || widget.reserveErrorSpace
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.inputLabelGap),
                  child: Text(
                    hasError ? errorText : ' ',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.error,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final validator = widget.validator;
    if (validator == null) return _field(widget.error);
    return FormField<String>(
      validator: (_) => validator(widget.controller.text),
      builder: (field) => _field(widget.error ?? field.errorText),
    );
  }
}

/// Label above an [AppInputBox] — shared by the non-text fields below.
class _Labeled extends StatelessWidget {
  final String? label;
  final Widget child;

  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    if (label == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          style: context.text.titleSmall?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
        const SizedBox(height: AppDimens.inputLabelGap),
        child,
      ],
    );
  }
}

/// Dropdown in the standard input box, label above.
class AppDropdownField<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final String? hint;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.label,
    this.prefixIcon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final enabled = onChanged != null;
    return _Labeled(
      label: label,
      child: AppInputBox(
        filled: value != null,
        enabled: enabled,
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(prefixIcon, size: AppDimens.iconMd, color: v.grayText),
              const SizedBox(width: AppDimens.space12),
            ],
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: items.contains(value) ? value : null,
                  isExpanded: true,
                  hint: hint == null
                      ? null
                      : Text(
                          hint!,
                          style: context.text.bodyMedium
                              ?.copyWith(color: v.grayText),
                        ),
                  style: context.text.bodyMedium?.copyWith(
                    color: enabled ? context.colors.onSurface : v.grayText,
                  ),
                  dropdownColor: v.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  icon: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppDimens.space8,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: v.grayText,
                    ),
                  ),
                  items: [
                    for (final item in items)
                      DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          itemLabel(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only value in the standard input box (optionally tappable, e.g. a
/// date picker).
class AppDisplayField extends StatelessWidget {
  final String? label;
  final String value;
  final String? placeholder;
  final IconData? prefixIcon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const AppDisplayField({
    super.key,
    required this.value,
    this.label,
    this.placeholder,
    this.prefixIcon,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final empty = value.isEmpty;
    return _Labeled(
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AppInputBox(
          filled: !empty,
          enabled: onTap != null,
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: AppDimens.iconMd, color: v.grayText),
                const SizedBox(width: AppDimens.space12),
              ],
              Expanded(
                child: Text(
                  empty ? (placeholder ?? '') : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: empty || onTap == null
                        ? v.grayText
                        : context.colors.onSurface,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimens.space8,
                  ),
                  child: Icon(trailingIcon, color: v.grayText),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rejects edits that don't match [pattern] (keeps the previous value).
class _RegexFormatter extends TextInputFormatter {
  final String pattern;

  const _RegexFormatter(this.pattern);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RegExp(pattern).hasMatch(newValue.text) ? newValue : oldValue;
}
