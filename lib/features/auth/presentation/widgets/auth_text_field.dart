import 'package:flutter/material.dart';

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
      });
      if (!_focusNode.hasFocus && widget.validate != null) {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final containerColor = widget.error != null ? colors.surface : Theme.of(context).scaffoldBackgroundColor;
    final isAvailable = widget.error?.toLowerCase().contains('available') ?? false;

    final indicatorColor = isAvailable
        ? const Color(0xFF2E7D32)
        : widget.error != null
            ? colors.error
            : _focused
                ? colors.primary
                : colors.outline;

    final localPasswordError = widget.showValidation &&
            widget.isPassword &&
            widget.value.isNotEmpty &&
            widget.value.length < 8
        ? 'Password must be at least 8 characters'
        : null;

    final showErrText = widget.error ?? localPasswordError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
              ),
        ),
        const SizedBox(height: 4.0),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: indicatorColor, width: _focused ? 2.0 : 1.0),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
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
                      obscureText: widget.isPassword && !_passwordVisible,
                      keyboardType: widget.keyboardType,
                      maxLines: widget.singleLine ? 1 : null,
                      enableInteractiveSelection: !widget.isPassword, // Disable copy/paste menu on password
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: widget.error != null && !isAvailable ? colors.error : colors.onSurface,
                          ),
                      cursorColor: colors.primary,
                      onChanged: (text) {
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
                if (widget.value.isNotEmpty && widget.error != null && !isAvailable)
                  Icon(
                    Icons.error_outline,
                    color: colors.error,
                    size: 22,
                  )
                else if (widget.isPassword)
                  IconButton(
                    icon: CustomPaint(
                      size: const Size(22, 22),
                      painter: _EyePainter(
                        visible: _passwordVisible,
                        color: widget.error != null
                            ? colors.error
                            : _focused
                                ? colors.primary
                                : colors.onSurface,
                        strikeProgress: _strikeController.value,
                      ),
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
                    tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        if (widget.isPassword)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  showErrText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                ),
              ),
              if (widget.showForgot && widget.onForgotPassword != null)
                GestureDetector(
                  onTap: widget.onForgotPassword,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      'Forgot password?',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.onSurface,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                )
              else
                const SizedBox(),
            ],
          )
        else
          Text(
            widget.error ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isAvailable ? const Color(0xFF2E7D32) : colors.error,
                ),
          ),
      ],
    );
  }
}

class _EyePainter extends CustomPainter {
  final bool visible;
  final Color color;
  final double strikeProgress;

  _EyePainter({
    required this.visible,
    required this.color,
    required this.strikeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final width = size.width;
    final height = size.height;

    // Draw eye boundaries (top & bottom curve)
    final eyePath = Path();
    eyePath.moveTo(0, height / 2);
    eyePath.quadraticBezierTo(width / 2, -height / 4, width, height / 2);
    eyePath.quadraticBezierTo(width / 2, height * 5 / 4, 0, height / 2);
    canvas.drawPath(eyePath, paint);

    // Draw pupil circle
    final pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(width / 2, height / 2), width / 5, pupilPaint);

    // Draw partial diagonal strike line when not visible
    if (strikeProgress > 0.0) {
      final strikePaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(0, height),
        Offset(width * strikeProgress, height * (1.0 - strikeProgress)),
        strikePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EyePainter oldDelegate) {
    return oldDelegate.visible != visible ||
        oldDelegate.color != color ||
        oldDelegate.strikeProgress != strikeProgress;
  }
}

// Wrapper fields matching Jetpack Compose wrappers
class AuthEmailField extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? validate;

  const AuthEmailField({
    super.key,
    required this.value,
    required this.label,
    required this.onChange,
    this.error,
    this.validate,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: 'Enter Email',
      error: error,
      validate: validate,
      keyboardType: TextInputType.emailAddress,
    );
  }
}

class AuthUsernameField extends StatelessWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChange;
  final String? error;
  final VoidCallback? validate;

  const AuthUsernameField({
    super.key,
    required this.value,
    required this.label,
    required this.onChange,
    this.error,
    this.validate,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: 'Enter Username',
      error: error,
      validate: validate,
      maxLength: 20,
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
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: 'Enter Password',
      isPassword: true,
      error: error,
      onForgotPassword: onForgotPassword,
      showForgot: showForgot,
      validate: validate,
      keyboardType: TextInputType.visiblePassword,
      showValidation: showValidation,
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

  const AuthNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.error,
    this.validate,
    this.showValidation = false,
  });

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: label,
      value: value,
      onChange: onChange,
      placeholder: 'Enter Otp',
      error: error,
      showForgot: false,
      validate: validate,
      keyboardType: TextInputType.number,
      showValidation: showValidation,
    );
  }
}
