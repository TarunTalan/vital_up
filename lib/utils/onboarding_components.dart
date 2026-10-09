import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';

/// Shared scaffold for every onboarding step — Figma `onboarding/<step>`:
/// back button + step counter, centred Large Title (+ body 16 med subtitle),
/// scrollable content and a pinned Skip / Next bar.
class OnboardingLayout extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String title;
  final String? subtitle;
  final bool nextEnabled;
  final bool showSkip;
  final String nextLabel;
  final bool fullBleedChild;
  final bool handleSystemBack;
  final double? titleTopSpace;
  final double? titleBottomSpace;
  final bool showBack;
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
    this.showBack = true,
    this.nextLabel = "Next",
    this.fullBleedChild = false,
    this.handleSystemBack = true,
    this.titleTopSpace,
    this.titleBottomSpace,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final gutter = context.gutter;

    Widget padded(Widget w) => Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: w,
    );

    final scaffold = GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AppDimens.space16),
          child: Padding(
            padding: EdgeInsets.only(
              top: AppDimens.space16,
              bottom: isKeyboardOpen ? 0 : context.h(AppDimens.space16),
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimens.maxContentWidth,
                ),
                child: OnboardingBottomBar(
                  onNext: onNext,
                  onSkip: onSkip,
                  nextEnabled: nextEnabled,
                  showSkip: showSkip,
                  nextLabel: nextLabel,
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppDimens.glassBlur / 2,
                  sigmaY: AppDimens.glassBlur / 2,
                ),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            SafeArea(
              bottom: false,
              child: ResponsiveCenter(
                child: Column(
                  children: [
                    const SizedBox(height: AppDimens.space16),
                    padded(OnboardingTopBar(onBack: onBack, step: step, showBack: showBack)),
                    Expanded(
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                SizedBox(
                                  height:
                                      titleTopSpace ??
                                      (isKeyboardOpen
                                          ? AppDimens.space16
                                          : context.h(AppDimens.space48)),
                                ),
                                padded(
                                  Text(
                                    title,
                                    style: context.text.displayLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: AppDimens.space12),
                                  padded(
                                    Text(
                                      subtitle!,
                                      style: context.text.titleSmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                SizedBox(
                                  height: isKeyboardOpen
                                      ? AppDimens.space16
                                      : (titleBottomSpace ??
                                            context.h(AppDimens.space48)),
                                ),
                                fullBleedChild ? child : padded(child),
                                SizedBox(
                                  height: isKeyboardOpen
                                      ? AppDimens.space16
                                      : AppDimens.space40,
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
          ],
        ),
      ),
    );

    if (!handleSystemBack || !showBack) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (MediaQuery.viewInsetsOf(context).bottom > 0.0) {
          FocusScope.of(context).unfocus();
        } else {
          onBack();
        }
      },
      child: scaffold,
    );
  }
}

class OnboardingTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final int step;
  final bool showBack;

  const OnboardingTopBar({
    super.key, 
    required this.onBack, 
    required this.step,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack) BackIcon(onClick: onBack) else const SizedBox(width: AppDimens.space48),
        const Spacer(),
        Text("$step/7", style: context.text.headlineSmall),
      ],
    );
  }
}

/// Skip (Figma `button/ sec`, #D8D8D8 hairline) + Next (`button/ pri`).
/// Buttons keep the Figma 108dp width as a minimum and grow with the label.
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
    const minWidth = BoxConstraints(minWidth: AppDimens.actionButtonMinWidth);

    return Padding(
      padding: context.pagePadding,
      child: Row(
        children: [
          if (showSkip)
            ConstrainedBox(
              constraints: minWidth,
              child: AppSecondaryButton(
                label: "Skip",
                expand: false,
                borderColor: context.vColors.hairline,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSkip();
                },
              ),
            ),
          const Spacer(),
          ConstrainedBox(
            constraints: minWidth,
            child: AppPrimaryButton(
              label: nextLabel,
              expand: false,
              enabled: nextEnabled,
              showRightArrow: true,
              onTap: () {
                HapticFeedback.lightImpact();
                onNext();
              },
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
      error: widget.isError
          ? (widget.showErrorText ? (widget.error ?? "Required") : "")
          : (widget.showErrorText ? widget.error : null),
      showValidation: widget.showErrorText,
      maxLength: widget.maxLength > 0 ? widget.maxLength : InputLimits.shortText,
      enabled: !widget.readOnly,
      showForgot: false,
      reserveErrorSpace: false,
      autofocus: widget.autofocus,
    );
  }
}

/// Figma `num input`: glass +/- steppers around a value box. The value box
/// gets a 2dp primary border + glow while focused and turns red on error.
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
  State<OnboardingNumberField<T>> createState() =>
      _OnboardingNumberFieldState<T>();
}

class _OnboardingNumberFieldState<T extends num>
    extends State<OnboardingNumberField<T>> {
  late TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() => _focused = _focusNode.hasFocus);
      });
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
    _focusNode.dispose();
    super.dispose();
  }

  void _decrement() {
    if (widget.value == null) {
      HapticFeedback.lightImpact();
      widget.onValueChange(widget.min);
    } else if (widget.value! > widget.min) {
      HapticFeedback.lightImpact();
      final newValue = widget.value! - widget.step;
      if (T == int) {
        widget.onValueChange(
          newValue.toInt().clamp(widget.min, widget.max) as T,
        );
      } else {
        final rounded = double.parse(newValue.toStringAsFixed(1));
        widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _increment() {
    if (widget.value == null) {
      HapticFeedback.lightImpact();
      final startVal = widget.min + widget.step;
      if (T == int) {
        widget.onValueChange(
          startVal.toInt().clamp(widget.min, widget.max) as T,
        );
      } else {
        final rounded = double.parse(startVal.toStringAsFixed(1));
        widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
      }
    } else if (widget.value! < widget.max) {
      HapticFeedback.lightImpact();
      final newValue = widget.value! + widget.step;
      if (T == int) {
        widget.onValueChange(
          newValue.toInt().clamp(widget.min, widget.max) as T,
        );
      } else {
        final rounded = double.parse(newValue.toStringAsFixed(1));
        widget.onValueChange(rounded.clamp(widget.min, widget.max) as T);
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _onChanged(String text) {
    if (text.isEmpty) {
      // Cleared to retype: report "no value" instead of snapping to min,
      // which refilled the box and made it impossible to clear.
      widget.onValueChange(null);
      return;
    }

    if (T == int && text.length > 1 && text.startsWith('0')) {
      final cleanText = int.tryParse(text)?.toString() ?? text;
      if (cleanText != text) {
        _controller.text = cleanText;
        _controller.selection = TextSelection.collapsed(
          offset: cleanText.length,
        );
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
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        } else {
          widget.onValueChange(intValue as T);
        }
      } else {
        if (parsed > widget.max) {
          HapticFeedback.heavyImpact();
          widget.onValueChange(widget.max);
          _controller.text = widget.max.toString();
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        } else {
          widget.onValueChange(parsed as T);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;
    final Color bgColor;
    final Color borderColor;
    final double borderWidth;
    if (widget.isError) {
      bgColor = v.errorFill!;
      borderColor = colors.error;
      borderWidth = AppDimens.borderThick;
    } else if (_focused) {
      bgColor = v.glassFill!;
      borderColor = colors.primary;
      borderWidth = AppDimens.borderThick;
    } else {
      bgColor = v.glassFill!;
      borderColor = v.glassBorder!;
      borderWidth = AppDimens.borderThin;
    }
    final valueColor = widget.isError ? colors.error : v.preText;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showButtons) ...[
          _StepperButton(icon: Icons.remove_rounded, onTap: _decrement),
          const SizedBox(width: AppDimens.space8),
        ],
        AnimatedContainer(
          duration: AppDurations.fast,
          width: AppDimens.numberFieldWidth,
          height: AppDimens.numberFieldHeight,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: _focused && !widget.isError
                ? AppShadows.inputFocus
                : null,
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: T != int,
                ),
                inputFormatters: [
                  if (T == int)
                    FilteringTextInputFormatter.digitsOnly
                  else
                    // One decimal point at most ("1.2.3" can't be parsed).
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                          ? newValue
                          : oldValue,
                    ),
                  LengthLimitingTextInputFormatter(
                    widget.max.toInt().toString().length + (T == int ? 0 : 2),
                  ),
                ],
                textAlign: TextAlign.center,
                onTapOutside: (event) {},
                autofocus: widget.autofocus,
                cursorColor: colors.primary,
                style: context.text.headlineLarge?.copyWith(color: valueColor),
                decoration: InputDecoration(
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '_ _',
                  hintStyle: context.text.headlineLarge?.copyWith(
                    color: v.preText,
                  ),
                ),
                onChanged: _onChanged,
              ),
              if (widget.suffixText != null)
                Positioned(
                  right: AppDimens.space8,
                  child: Text(
                    widget.suffixText!,
                    style: context.text.bodyMedium?.copyWith(color: v.grayText),
                  ),
                ),
            ],
          ),
        ),
        if (widget.showButtons) ...[
          const SizedBox(width: AppDimens.space8),
          _StepperButton(icon: Icons.add_rounded, onTap: _increment),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return Material(
      color: v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: v.glassBorder!, width: AppDimens.borderThin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppDimens.numberStepperSize,
          child: Icon(
            icon,
            size: AppDimens.iconLg,
            color: context.colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Small grey caption under a number field (e.g. "Beats per minute").
class OnboardingFieldCaption extends StatelessWidget {
  final String text;

  const OnboardingFieldCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.text.bodySmall?.copyWith(color: context.vColors.grayText),
    );
  }
}

/// Tappable field styled like Figma `input/text` (used for the date picker).
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
    final v = context.vColors;
    final colors = context.colors;
    final isEmpty = value.isEmpty;
    final radius = BorderRadius.circular(AppDimens.radiusInput);

    final Color bgColor = isError
        ? v.errorFill!
        : (isEmpty ? v.glassFill! : v.primaryFill!);
    final BorderSide border = isError
        ? BorderSide(color: colors.error, width: AppDimens.borderThick)
        : BorderSide(color: v.glassBorder!, width: AppDimens.borderThin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.titleSmall),
        const SizedBox(height: AppDimens.inputLabelGap),
        Material(
          color: bgColor,
          shape: RoundedRectangleBorder(borderRadius: radius, side: border),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onClick,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppDimens.inputHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space16,
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                isEmpty ? placeholder : value,
                style: isEmpty
                    ? context.text.bodyMedium?.copyWith(color: v.grayText)
                    : context.text.bodyLarge?.copyWith(
                        color: isError ? colors.error : colors.onSurface,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unit picker — Figma glass `button/ sec` with grey label + caret, same
/// height as the inputs.
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
    final v = context.vColors;
    return Container(
      height: AppDimens.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space16),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!, width: AppDimens.borderThin),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUnit,
          icon: Padding(
            padding: const EdgeInsets.only(left: AppDimens.space8),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: AppDimens.iconXs,
              color: v.grayText,
            ),
          ),
          dropdownColor: v.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          style: context.text.bodyMedium?.copyWith(color: v.grayText),
          items: units.map((String unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(
                unit,
                style: context.text.bodyMedium?.copyWith(color: v.grayText),
              ),
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

/// Selectable option tile — Figma onboarding/act & extra: glass tile that
/// turns into a cyan sheen with a cyan border when selected.
class OnboardingOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? leading;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final double radius;
  final TextStyle? labelStyle;
  final bool expand;

  const OnboardingOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.leading,
    this.minHeight = AppDimens.optionTileHeight,
    this.padding = const EdgeInsets.all(AppDimens.space16),
    this.radius = AppDimens.radiusCard,
    this.labelStyle,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final borderRadius = BorderRadius.circular(radius);
    final style = (labelStyle ?? context.text.titleSmall)?.copyWith(
      color: context.colors.onSurface,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: isSelected ? null : v.glassFill,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.3, 1.0],
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.35),
                  ],
                )
              : null,
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected ? v.primaryBorder! : v.glassBorder!,
            width: AppDimens.borderThin,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: padding,
              child: Center(
                widthFactor: expand ? null : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppDimens.space16),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: style,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline info note — Figma `toast/info`. Thin wrapper over [AppInfoNote].
class NoteRow extends StatelessWidget {
  final IconData iconRes;
  final String text;

  const NoteRow({
    super.key,
    this.iconRes = Icons.info_outline_rounded,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AppInfoNote(message: text, icon: iconRes);
  }
}
