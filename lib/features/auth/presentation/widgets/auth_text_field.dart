import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';

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
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> with SingleTickerProviderStateMixin {
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
      if (!_focusNode.hasFocus && widget.error == null && widget.validate != null) {
        widget.validate!();
      }
    });

    _strikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
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
      // Disallow spaces and non-printable characters for generic fields
      filtered = input.replaceAll(RegExp(r'[^\x21-\x7E]'), '');
    }

    return filtered.length > maxLen ? filtered.substring(0, maxLen) : filtered;
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF757575),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Normal state: light gray fill (#F5F5F5), no border.
    // Error state: light pink fill with red border.
    // Focused state: white fill with cyan border.
    final baseColor = const Color(0xFFD8D8D8);
    // rgba(216, 216, 216, 0.3) to allow background blobs to blur through
    final containerColor = baseColor.withValues(alpha: 0.3);
    final isAvailable = widget.isAvailable == true;

    // Border color: rgba(20, 156, 179, 1) when focused; green for success, red for error, else rgba(216, 216, 216, 1)
    final borderColor = isAvailable
        ? const Color(0xFF2E7D32)
        : widget.error != null
            ? colors.error
            : _focused
                ? const Color(0xFF149CB3) // Focused: rgba(20, 156, 179, 1)
                : baseColor;

    final localPasswordError = widget.showValidation &&
            widget.isPassword &&
            widget.value.isNotEmpty &&
            widget.value.length < 8
        ? 'Password must be at least 8 characters'
        : null;

    final showErrText = isAvailable
        ? 'Username is available'
        : (widget.error ?? localPasswordError);

    final hasError = isAvailable || (showErrText != null && showErrText.isNotEmpty);
    final showForgotRow = widget.isPassword && widget.showForgot && widget.onForgotPassword != null;

    final inputHeight = AppTheme.responsiveInputHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
              ),
        ),
        SizedBox(height: AppTheme.responsiveHeight(context, 6.0)),
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30.6, sigmaY: 30.6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: inputHeight,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                    border: Border.all(
                      color: borderColor,
                      width: _focused ? 2.0 : 1.0, // 2dp when selected, 1dp otherwise
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: widget.enabled,
                              obscureText: widget.isPassword && !_passwordVisible,
                              keyboardType: widget.keyboardType,
                              textInputAction: widget.textInputAction,
                              onSubmitted: widget.onSubmitted,
                              autofillHints: widget.autofillHints,
                              maxLines: widget.singleLine ? 1 : null,
                              enableInteractiveSelection: !widget.isPassword, // Disable copy/paste menu on password
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: widget.error != null && !isAvailable
                                        ? colors.error
                                        : _focused
                                            ? const Color(0xFF149CB3) // Selected text color: rgba(20, 156, 179, 1)
                                            : colors.onSurface,
                                  ),
                              cursorColor: colors.primary,
                              onChanged: (text) {
                                setState(() {
                                  _showRequirements = false;
                                });
                                final sanitized = _sanitizeInput(text);
                                if (sanitized != text) {
                                  _controller.value = _controller.value.copyWith(
                                    text: sanitized,
                                    selection: TextSelection.collapsed(offset: sanitized.length),
                                  );
                                }
                                widget.onChange(sanitized);
                              },
                              decoration: InputDecoration(
                                hintText: widget.placeholder,
                                hintStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: colors.onTertiary,
                                    ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        // Trailing icons
                        if (widget.isPassword) ...[
                          if (widget.error != null && widget.showRequirementsInfo)
                            IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: colors.error,
                                size: 22,
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
                              color: widget.error != null
                                  ? colors.error
                                  : _focused
                                      ? colors.primary
                                      : colors.onSurface,
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
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF149CB3)),
                                ),
                              ),
                            )
                          else if (isAvailable)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFF2E7D32),
                                size: 20,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Floating requirements bubble above the textfield
            if (widget.isPassword && _showRequirements)
              Positioned(
                left: 16,
                bottom: inputHeight + 8.0, // Floating exactly above the textfield
                child: CustomPaint(
                  painter: SpeechBubblePainter(
                    backgroundColor: Colors.white.withValues(alpha: 0.96),
                    borderColor: const Color(0xFFD8D8D8),
                  ),
                  child: Container(
                    width: 290,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20), // Bottom space for speech arrow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Password Requirements',
                          style: TextStyle(
                            fontFamily: 'SFProRounded',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1C1C1C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildBullet('Password must be at least 8 characters'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppTheme.responsiveHeight(context, 5.0)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SizedBox(
                height: 16.0,
                child: Text(
                  hasError ? (showErrText ?? '') : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: (isAvailable && !widget.isPassword)
                            ? const Color(0xFF2E7D32)
                            : colors.error,
                        fontSize: 11.0,
                      ),
                ),
              ),
            ),
            if (showForgotRow)
              GestureDetector(
                onTap: widget.onForgotPassword,
                child: Text(
                  'Forgot password?',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                        decoration: TextDecoration.underline,
                        fontSize: 13.0,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SvgEyeIcon extends StatelessWidget {
  final bool visible;
  final Color color;

  const _SvgEyeIcon({
    required this.visible,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final svgWidget = SvgPicture.asset(
      'assets/icons/Eye.svg',
      width: 22,
      height: 22,
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
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(2, size.height - 2),
      Offset(size.width - 2, 2),
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
        showForgot ? AutofillHints.password : AutofillHints.newPassword
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
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final radius = 12.0;
    final arrowHeight = 8.0;
    final arrowWidth = 12.0;
    final arrowX = size.width - 45.0;

    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
      ..lineTo(size.width, size.height - radius - arrowHeight)
      ..arcToPoint(Offset(size.width - radius, size.height - arrowHeight), radius: Radius.circular(radius))
      ..lineTo(arrowX + arrowWidth / 2, size.height - arrowHeight)
      ..lineTo(arrowX, size.height)
      ..lineTo(arrowX - arrowWidth / 2, size.height - arrowHeight)
      ..lineTo(radius, size.height - arrowHeight)
      ..arcToPoint(Offset(0, size.height - radius - arrowHeight), radius: Radius.circular(radius))
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
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
