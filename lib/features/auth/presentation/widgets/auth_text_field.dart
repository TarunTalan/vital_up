import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

class AuthTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final String placeholder;
  final bool isPassword;
  final String? error;
  final VoidCallback? onForgotPassword;
  final bool showForgot;
  final VoidCallback? validate;
  final TextInputType keyboardType;
  final bool singleLine;
  final bool showValidation;
  final int maxLength;
  final bool showRequirementsInfo;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool? isAvailable;
  final bool isChecking;
  final bool reserveErrorSpace;
  final bool autofocus;

  const AuthTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.placeholder = '',
    this.isPassword = false,
    this.error,
    this.onForgotPassword,
    this.showForgot = true,
    this.validate,
    this.keyboardType = TextInputType.text,
    this.singleLine = true,
    this.showValidation = false,
    this.maxLength = 1000,
    this.showRequirementsInfo = false,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.isAvailable,
    this.isChecking = false,
    this.reserveErrorSpace = true,
    this.autofocus = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  // Eye icon toggle state
  bool _manuallyToggledVisible = false;
  bool _passwordVisible = false;
  bool _showingDueToError = false;
  bool _showRequirements = false;

  // Controller for diagonal strikethrough animation
  late AnimationController _strikeController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      setState(() {
        _focused = _focusNode.hasFocus;
        if (!_focused) {
          _showRequirements = false;
        }
      });
      if (!_focusNode.hasFocus &&
          widget.error == null &&
          widget.validate != null) {
        widget.validate!();
      }
    });

    _strikeController = AnimationController(
      vsync: this,
      duration: AppDurations.medium,
    );

    // Initial state matching password visibility
    if (widget.isPassword && !_passwordVisible) {
      _strikeController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }

    // When error appears, temporarily show password
    if (widget.isPassword) {
      if (widget.error != null && !_showingDueToError) {
        _showingDueToError = true;
        setState(() {
          _passwordVisible = true;
        });
        _strikeController.reverse();
      } else if (widget.error == null && _showingDueToError) {
        _showingDueToError = false;
        setState(() {
          _passwordVisible = _manuallyToggledVisible;
        });
        if (_passwordVisible) {
          _strikeController.reverse();
        } else {
          _strikeController.forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _strikeController.dispose();
    super.dispose();
  }

  String _sanitizeInput(String input) {
    final maxLen = widget.isPassword ? 16 : widget.maxLength;
    String filtered = input;

    if (widget.keyboardType == TextInputType.emailAddress) {
      filtered = input.replaceAll(RegExp(r'[^A-Za-z0-9@._%+\-]'), '');
    } else if (widget.keyboardType == TextInputType.number) {
      filtered = input.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      // Disallow control characters and newlines, but allow spaces and standard text
      filtered = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    }

    return filtered.length > maxLen ? filtered.substring(0, maxLen) : filtered;
  }

  Widget _buildBullet(String text) {
    final style = context.text.bodyMedium?.copyWith(
      color: context.vColors.grayText,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final isAvailable = widget.isAvailable == true;
    final hasFieldError = widget.error != null && !isAvailable;
    final isFilled = widget.value.isNotEmpty;

    final textColor = hasFieldError
        ? colors.error
        : _focused
        ? AppColors.primaryActive
        : colors.onSurface;

    final iconColor = hasFieldError
        ? colors.error
        : _focused
        ? colors.primary
        : colors.onSurface;

    final localPasswordError =
        widget.showValidation &&
            widget.isPassword &&
            widget.value.isNotEmpty &&
            widget.value.length < 8
        ? 'Password must be at least 8 characters'
        : null;

    final showErrText = isAvailable
        ? 'Username is available'
        : (widget.error ?? localPasswordError);

    final hasError =
        isAvailable || (showErrText != null && showErrText.isNotEmpty);
    final showForgotRow =
        widget.isPassword &&
        widget.showForgot &&
        widget.onForgotPassword != null;

    final inputHeight = AppTheme.responsiveInputHeight(context);

    final helperStyle = context.text.bodyLarge?.copyWith(
      color: (isAvailable && !widget.isPassword) ? v.success : colors.error,
    );
    final forgotStyle = context.text.bodyMedium?.copyWith(
      color: colors.onSurface,
      decoration: TextDecoration.underline,
    );

    Widget helperText(String text) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: helperStyle,
    );

    Widget forgotLink() => GestureDetector(
      onTap: widget.onForgotPassword,
      child: Text('Forgot password?', style: forgotStyle),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.text.titleSmall?.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: AppDimens.inputLabelGap),
        Stack(
          clipBehavior: Clip.none,
          children: [
            AppInputBox(
              focused: _focused,
              filled: isFilled,
              hasError: hasFieldError,
              success: isAvailable,
              enabled: widget.enabled,
              multiline: !widget.singleLine,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      enabled: widget.enabled,
                      obscureText: widget.isPassword && !_passwordVisible,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      onSubmitted: widget.onSubmitted,
                      autofillHints: widget.autofillHints,
                      maxLines: widget.singleLine ? 1 : null,
                      enableInteractiveSelection: !widget.isPassword,
                      onTapOutside: (event) {},
                      style: context.text.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                      cursorColor: hasFieldError
                          ? colors.error
                          : colors.primary,
                      onChanged: (text) {
                        setState(() {
                          _showRequirements = false;
                        });
                        final sanitized = _sanitizeInput(text);
                        if (sanitized != text) {
                          _controller.value = _controller.value.copyWith(
                            text: sanitized,
                            selection: TextSelection.collapsed(
                              offset: sanitized.length,
                            ),
                          );
                        }
                        widget.onChange(sanitized);
                      },
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: context.text.bodyMedium?.copyWith(
                          color: hasFieldError ? colors.error : v.grayText,
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
                  if (widget.isPassword) ...[
                    if (widget.error != null && widget.showRequirementsInfo)
                      IconButton(
                        icon: Icon(
                          Icons.info_outline,
                          color: colors.error,
                          size: AppDimens.iconMd,
                        ),
                        onPressed: () {
                          setState(() {
                            _showRequirements = !_showRequirements;
                          });
                        },
                        tooltip: 'Show requirements',
                      ),
                    IconButton(
                      icon: _SvgEyeIcon(
                        visible: _passwordVisible,
                        color: iconColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                          _manuallyToggledVisible = _passwordVisible;
                          _showingDueToError = false;
                        });
                        if (_passwordVisible) {
                          _strikeController.reverse();
                        } else {
                          _strikeController.forward();
                        }
                      },
                    ),
                  ] else ...[
                    if (widget.isChecking)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppDimens.space12,
                        ),
                        child: SizedBox.square(
                          dimension: AppDimens.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: AppDimens.borderThick,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryActive,
                            ),
                          ),
                        ),
                      )
                    else if (isAvailable)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppDimens.space12,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: v.success,
                          size: AppDimens.iconMd,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (widget.isPassword && _showRequirements)
              PositionedDirectional(
                start: AppDimens.space16,
                end: AppDimens.space16,
                bottom: inputHeight + AppDimens.space8,
                child: CustomPaint(
                  painter: SpeechBubblePainter(
                    backgroundColor: v.surfaceElevated!.withValues(alpha: 0.96),
                    borderColor: v.hairline!,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.space16,
                      AppDimens.space12,
                      AppDimens.space16,
                      AppDimens.space20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Password Requirements',
                          style: context.text.titleSmall?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space6),
                        _buildBullet('Password must be at least 8 characters'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.reserveErrorSpace)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.inputLabelGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: helperText(showErrText ?? ' ')),
                if (showForgotRow) ...[
                  const SizedBox(width: AppDimens.space8),
                  forgotLink(),
                ],
              ],
            ),
          )
        else
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: (hasError || showForgotRow)
                ? Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimens.inputLabelGap,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasError)
                          Expanded(child: helperText(showErrText ?? ''))
                        else
                          const Spacer(),
                        if (showForgotRow) ...[
                          const SizedBox(width: AppDimens.space8),
                          forgotLink(),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
      ],
    );
  }
}

class _SvgEyeIcon extends StatelessWidget {
  final bool visible;
  final Color color;

  const _SvgEyeIcon({required this.visible, required this.color});

  @override
  Widget build(BuildContext context) {
    final svgWidget = SvgPicture.asset(
      'assets/icons/Eye.svg',
      width: AppDimens.iconMd,
      height: AppDimens.iconMd,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (visible) {
      return svgWidget;
    }

    return CustomPaint(
      foregroundPainter: _SlashPainter(color: color),
      child: svgWidget,
    );
  }
}

class _SlashPainter extends CustomPainter {
  final Color color;

  _SlashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppDimens.borderThick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const inset = AppDimens.space2;
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(size.width - inset, inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// Wrapper fields matching Jetpack Compose wrappers
class AuthEmailField extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? validate;
  final String placeholder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLength;

  const AuthEmailField({
    super.key,
    required this.value,
    required this.label,
    required this.onChange,
    this.error,
    this.validate,
    this.placeholder = 'Enter your email id',
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.maxLength = 250,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: placeholder,
      error: error,
      validate: validate,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.email],
      enabled: enabled,
      maxLength: maxLength,
    );
  }
}

class AuthUsernameField extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? validate;
  final String placeholder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLength;

  final bool? isAvailable;
  final bool isChecking;

  const AuthUsernameField({
    super.key,
    required this.value,
    required this.label,
    required this.onChange,
    this.error,
    this.validate,
    this.placeholder = 'Enter your name',
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.maxLength = 20,
    this.isAvailable,
    this.isChecking = false,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: placeholder,
      error: error,
      validate: validate,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.username],
      enabled: enabled,
      isAvailable: isAvailable,
      isChecking: isChecking,
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? onForgotPassword;
  final bool showForgot;
  final VoidCallback? validate;
  final bool showValidation;
  final String placeholder;
  final bool showRequirementsInfo;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const AuthPasswordField({
    super.key,
    required this.value,
    required this.label,
    required this.onChange,
    this.error,
    this.onForgotPassword,
    this.showForgot = true,
    this.validate,
    this.showValidation = false,
    this.placeholder = 'Enter password',
    this.showRequirementsInfo = false,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: placeholder,
      isPassword: true,
      error: error,
      onForgotPassword: onForgotPassword,
      showForgot: showForgot,
      validate: validate,
      keyboardType: TextInputType.visiblePassword,
      showValidation: showValidation,
      showRequirementsInfo: showRequirementsInfo,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: [
        showForgot ? AutofillHints.password : AutofillHints.newPassword,
      ],
      enabled: enabled,
    );
  }
}

class AuthNumberField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? validate;
  final bool showValidation;
  final String placeholder;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AuthNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.error,
    this.validate,
    this.showValidation = false,
    this.placeholder = 'Enter Otp',
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: placeholder,
      error: error,
      showForgot: false,
      validate: validate,
      keyboardType: TextInputType.number,
      showValidation: showValidation,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.oneTimeCode],
    );
  }
}

/// Rounded speech bubble with a downward arrow near its trailing edge
/// (pointing at the requirements info icon inside the field).
class SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = AppDimens.borderThin
      ..style = PaintingStyle.stroke;

    const radius = AppDimens.radiusToast;
    const arrowHeight = AppDimens.space8;
    const arrowWidth = AppDimens.space12;
    final arrowX = size.width - AppDimens.space48;

    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, size.height - radius - arrowHeight)
      ..arcToPoint(
        Offset(size.width - radius, size.height - arrowHeight),
        radius: const Radius.circular(radius),
      )
      ..lineTo(arrowX + arrowWidth / 2, size.height - arrowHeight)
      ..lineTo(arrowX, size.height)
      ..lineTo(arrowX - arrowWidth / 2, size.height - arrowHeight)
      ..lineTo(radius, size.height - arrowHeight)
      ..arcToPoint(
        Offset(0, size.height - radius - arrowHeight),
        radius: const Radius.circular(radius),
      )
      ..lineTo(0, radius)
      ..arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      )
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
