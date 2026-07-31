import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';

class OnboardingColors {
  static const Color fieldBackground = Color.fromRGBO(186, 186, 186, 0.2);
  static const Color fieldBorder = Color.fromRGBO(186, 186, 186, 0.3);
}

class OnboardingStyle {
  static const double screenHorizontalPadding = AppTheme.hPadding;
  static const double screenTopSpacing = 24.0;
  static const double titleSubtitleSpacing = 8.0;
  static const double sectionSpacingLarge = 32.0;
  static const double sectionSpacingMedium = 16.0;
  static const double sectionSpacingSmall = 8.0;

  static const double controlButtonSizeWidth = 50.0;
  static const double controlButtonSizeHeight = AppTheme.inputHeight;
  static const double controlGap = 12.0;

  static const double numberFieldWidth = 102.0;
  static const double numberFieldHeight = AppTheme.inputHeight;
  static const double numberFieldCornerRadius = AppTheme.inputRadius;

  static const double bottomBarHeight = AppTheme.buttonHeight;
  static const double bottomBarPaddingBottom = 32.0;

  static const double labelFontSize = 16.0;
  static const double stepCounterFontSize = 20.0;

  static const double imageHorizontalPadding = screenHorizontalPadding;
}

class OnboardingLayout extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String title;
  final String? subtitle;
  final bool nextEnabled;
  final bool showSkip;
  final bool fullBleedChild;
  final double titleTopSpace;
  final double titleBottomSpace;
  final Widget child;

  const OnboardingLayout({
    super.key,
    required this.step,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.title,
    this.subtitle,
    this.nextEnabled = true,
    this.showSkip = true,
    this.fullBleedChild = false,
    this.titleTopSpace = 24.0,
    this.titleBottomSpace = 40.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0.0) {
          FocusScope.of(context).unfocus();
        } else {
          onBack();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(
            top: 16.0,
            bottom: OnboardingStyle.bottomBarPaddingBottom,
          ),
          child: OnboardingBottomBar(
            onNext: onNext,
            onSkip: onSkip,
            nextEnabled: nextEnabled,
            showSkip: showSkip,
          ),
        ),
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg.png', // Fallback to generic name if it doesn't exist yet
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            // Blur effect
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16.0), // Top margin above the bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                    child: OnboardingTopBar(onBack: onBack, step: step),
                  ),
                  const SizedBox(height: 16.0), // Padding below top bar to prevent hard clipping on scroll
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              SizedBox(height: titleTopSpace),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                                child: Text(
                                  title,
                                  style: Theme.of(context).textTheme.displayMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: OnboardingStyle.titleSubtitleSpacing),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                                  child: Text(
                                    subtitle!,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              Builder(
                                builder: (context) {
                                  final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                                  return SizedBox(height: isKeyboardOpen ? 16.0 : titleBottomSpace);
                                }
                              ),
                              fullBleedChild 
                                ? child 
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                                    child: child,
                                  ),
                              Builder(
                                builder: (context) {
                                  final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                                  return SizedBox(height: isKeyboardOpen ? 16.0 : 40.0);
                                }
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class OnboardingTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final int step;

  const OnboardingTopBar({
    super.key,
    required this.onBack,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackIcon(onClick: onBack),
          const Spacer(),
          Text(
            "$step/10",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: OnboardingStyle.stepCounterFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
  }
}

class OnboardingBottomBar extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool nextEnabled;
  final String nextLabel;
  final bool showSkip;

  const OnboardingBottomBar({
    super.key,
    required this.onNext,
    required this.onSkip,
    this.nextEnabled = true,
    this.nextLabel = "Next",
    this.showSkip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: OnboardingStyle.bottomBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showSkip)
            SizedBox(
              width: 108,
              child: SecondaryAuthButton(
                label: "Skip",
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSkip();
                },
                containerColor: Colors.transparent,
                borderColor: const Color.fromRGBO(216, 216, 216, 1),
                contentColor: Theme.of(context).colorScheme.onSurface,
              ),
            )
          else
            const SizedBox(width: 108), // Keep spacing consistent
          SizedBox(
            width: 108,
            child: PrimaryAuthButton(
              label: nextLabel,
              onTap: () {
                HapticFeedback.lightImpact();
                onNext();
              },
              enabled: nextEnabled,
              isLoading: false,
              showRightArrow: true,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChange;
  final String placeholder;
  final String? error;
  final bool isError;
  final bool showErrorText;
  final TextInputType keyboardType;
  final bool readOnly;
  final int maxLength;
  final bool autofocus;

  const OnboardingTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
    this.placeholder = "",
    this.error,
    this.isError = false,
    this.showErrorText = true,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.maxLength = -1,
    this.autofocus = false,
  });

  @override
  State<OnboardingTextField> createState() => _OnboardingTextFieldState();
}

class _OnboardingTextFieldState extends State<OnboardingTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant OnboardingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: widget.label,
      value: widget.value,
      onChange: widget.onChange,
      placeholder: widget.placeholder,
      keyboardType: widget.keyboardType,
      error: widget.showErrorText ? (widget.isError ? "Required" : widget.error) : null,
      showValidation: widget.showErrorText,
      maxLength: widget.maxLength > 0 ? widget.maxLength : 1000,
      enabled: !widget.readOnly,
      showForgot: false,
      reserveErrorSpace: false,
      autofocus: widget.autofocus,
    );
  }
}

class OnboardingNumberField<T extends num> extends StatefulWidget {
  final T? value;
  final ValueChanged<T?> onValueChange;
  final T min;
  final T max;
  final num step;
  final bool showButtons;
  final String? suffixText;
  final bool isError;
  final bool autofocus;

  const OnboardingNumberField({
    super.key,
    required this.value,
    required this.onValueChange,
    required this.min,
    required this.max,
    this.step = 1,
    this.showButtons = true,
    this.suffixText,
    this.isError = false,
    this.autofocus = false,
  });

  @override
  State<OnboardingNumberField<T>> createState() => _OnboardingNumberFieldState<T>();
}

class _OnboardingNumberFieldState<T extends num> extends State<OnboardingNumberField<T>> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant OnboardingNumberField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newVal = widget.value?.toString() ?? '';
    // Prevent overriding if the parsed value equals the internal value
    // (e.g. don't override "5." with "5.0")
    final currentParsed = double.tryParse(_controller.text);
    final newParsed = double.tryParse(newVal);
    
    if (newParsed != null && currentParsed == newParsed) {
      return;
    }

    if (newVal != _controller.text) {
      // Preserve cursor position when updating from external source (like +/- buttons)
      final selection = _controller.selection;
      _controller.text = newVal;
      if (selection.isValid && selection.end <= newVal.length) {
        _controller.selection = selection;
      } else {
        _controller.selection = TextSelection.collapsed(offset: newVal.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fieldShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
    );
    final colors = Theme.of(context).colorScheme;
    final bgColor = widget.isError ? colors.error.withValues(alpha: 0.12) : OnboardingColors.fieldBackground;
    final borderColor = widget.isError ? colors.error : OnboardingColors.fieldBorder;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.showButtons) ...[
          InkWell(
            onTap: () {
              if (widget.value == null) {
                HapticFeedback.lightImpact();
                widget.onValueChange(widget.min);
              } else if (widget.value! > widget.min) {
                HapticFeedback.lightImpact();
                final newValue = widget.value! - widget.step;
                if (T == int) {
                  widget.onValueChange(newValue.toInt().clamp(widget.min, widget.max) as T);
                } else {
                  final rounded = double.parse(newValue.toStringAsFixed(1));
                  widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
                }
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            customBorder: fieldShape,
            child: Container(
              width: OnboardingStyle.controlButtonSizeWidth,
              height: OnboardingStyle.controlButtonSizeHeight,
              decoration: BoxDecoration(
                color: OnboardingColors.fieldBackground,
                borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
                border: Border.all(color: OnboardingColors.fieldBorder),
              ),
              alignment: Alignment.center,
              child: const Text("−", style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: OnboardingStyle.controlGap),
        ],
        Container(
          width: OnboardingStyle.numberFieldWidth,
          height: OnboardingStyle.numberFieldHeight,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                autofocus: widget.autofocus,
                style: Theme.of(context).textTheme.headlineLarge,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (text) {
                  if (text.isEmpty) {
                    widget.onValueChange(widget.min);
                    return;
                  }
                  
                  if (T == int && text.length > 1 && text.startsWith('0')) {
                    final cleanText = int.tryParse(text)?.toString() ?? text;
                    if (cleanText != text) {
                      _controller.text = cleanText;
                      _controller.selection = TextSelection.collapsed(offset: cleanText.length);
                      text = cleanText;
                    }
                  }

                  final parsed = double.tryParse(text);
                  if (parsed != null) {
                    if (T == int) {
                      final intValue = parsed.toInt();
                      if (intValue > widget.max) {
                        HapticFeedback.heavyImpact();
                        widget.onValueChange(widget.max);
                        _controller.text = widget.max.toString();
                        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                      } else {
                        widget.onValueChange(intValue as T);
                      }
                    } else {
                      if (parsed > widget.max) {
                        HapticFeedback.heavyImpact();
                        widget.onValueChange(widget.max);
                        _controller.text = widget.max.toString();
                        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                      } else {
                        widget.onValueChange(parsed as T);
                      }
                    }
                  }
                },
              ),
              if (widget.suffixText != null)
                Positioned(
                  right: OnboardingStyle.sectionSpacingSmall,
                  child: Text(
                    widget.suffixText!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
        if (widget.showButtons) ...[
          const SizedBox(width: OnboardingStyle.controlGap),
          InkWell(
            onTap: () {
              if (widget.value == null) {
                HapticFeedback.lightImpact();
                final startVal = widget.min + widget.step;
                if (T == int) {
                  widget.onValueChange(startVal.toInt().clamp(widget.min, widget.max) as T);
                } else {
                  final rounded = double.parse(startVal.toStringAsFixed(1));
                  widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
                }
              } else if (widget.value! < widget.max) {
                HapticFeedback.lightImpact();
                final newValue = widget.value! + widget.step;
                if (T == int) {
                  widget.onValueChange(newValue.toInt().clamp(widget.min, widget.max) as T);
                } else {
                  final rounded = double.parse(newValue.toStringAsFixed(1));
                  widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
                }
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            customBorder: fieldShape,
            child: Container(
              width: OnboardingStyle.controlButtonSizeWidth,
              height: OnboardingStyle.controlButtonSizeHeight,
              decoration: BoxDecoration(
                color: OnboardingColors.fieldBackground,
                borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
                border: Border.all(color: OnboardingColors.fieldBorder),
              ),
              alignment: Alignment.center,
              child: const Text("+", style: TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ],
    );
  }
}

class OnboardingDateField extends StatelessWidget {
  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onClick;
  final bool isError;

  const OnboardingDateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onClick,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final vColors = Theme.of(context).extension<VitalUpColors>();
    final bgColor = vColors?.inputBorder?.withValues(alpha: 0.1) ?? OnboardingColors.fieldBackground;
    final bdColor = isError ? AppTheme.errorLightColor : (vColors?.inputBorder ?? OnboardingColors.fieldBorder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6.0),
        InkWell(
          onTap: onClick,
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.6, sigmaY: 30.6),
              child: Container(
                height: AppTheme.inputHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: isError 
                      ? AppTheme.errorLightColor.withValues(alpha: 0.1) 
                      : const Color(0xFFD8D8D8).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  border: Border.all(
                    color: isError 
                        ? AppTheme.errorLightColor 
                        : const Color(0xFFD8D8D8),
                  ),
                ),
                child: Text(
                  value.isEmpty ? placeholder : value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value.isEmpty ? (vColors?.grayText ?? Colors.grey) : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UnitDropdown extends StatelessWidget {
  final String selectedUnit;
  final List<String> units;
  final ValueChanged<String> onUnitSelected;

  const UnitDropdown({
    super.key,
    required this.selectedUnit,
    this.units = const ["kg", "lb"],
    required this.onUnitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 85,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: OnboardingColors.fieldBackground,
        borderRadius: BorderRadius.circular(OnboardingStyle.numberFieldCornerRadius),
        border: Border.all(color: OnboardingColors.fieldBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUnit,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          isExpanded: true,
          items: units.map((String unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(unit, style: Theme.of(context).textTheme.titleMedium),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              onUnitSelected(val);
            }
          },
        ),
      ),
    );
  }
}

class NoteRow extends StatelessWidget {
  final IconData iconRes;
  final String text;
  final Color borderColor;
  final Color textColor;

  const NoteRow({
    super.key,
    this.iconRes = Icons.info_outline,
    required this.text,
    this.borderColor = const Color.fromRGBO(52, 52, 52, 1),
    this.textColor = const Color.fromRGBO(117, 117, 117, 1),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(16.0),
      ),
      padding: const EdgeInsets.only(top: 6.0, bottom: 6.0, right: 6.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(iconRes, size: 20, color: textColor),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w300,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
