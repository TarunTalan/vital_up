import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/utils/onboarding_components.dart';

class HeightPage extends StatefulWidget {
  const HeightPage({super.key});

  @override
  State<HeightPage> createState() => _HeightPageState();
}

class _HeightPageState extends State<HeightPage> {
  bool _showErrors = false;
  bool _latestValid = true;

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      step: 2,
      onBack: () {
        setState(() => _showErrors = false);
        context.goNamed('health-personal-details');
      },
      onNext: () {
        if (!_latestValid) {
          setState(() {
            _showErrors = true;
          });
        } else {
          context.goNamed('health-weight');
        }
      },
      onSkip: () {
        setState(() => _showErrors = false);
        context.goNamed('health-weight');
      },
      title: "Your height",
      subtitle: "To tailor your health insights.",
      nextEnabled: true,
      child: _HeightContent(
        onValidityChange: (valid) {
          // Only rebuild on a real change: an unconditional setState here
          // rebuilt the child, which reported again, every frame.
          if (valid == _latestValid) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && valid != _latestValid) {
              setState(() => _latestValid = valid);
            }
          });
        },
        showErrors: _showErrors,
        onClearError: () {
          setState(() {
            _showErrors = false;
          });
        },
      ),
    );
  }
}

class _HeightContent extends StatefulWidget {
  final ValueChanged<bool> onValidityChange;
  final bool showErrors;
  final VoidCallback onClearError;

  const _HeightContent({
    required this.onValidityChange,
    this.showErrors = false,
    required this.onClearError,
  });

  @override
  State<_HeightContent> createState() => _HeightContentState();
}

class _HeightContentState extends State<_HeightContent> {
  int? _height = 120;
  int? _inches = 0;
  String _selectedUnit = "cm";
  
  @override
  void initState() {
    super.initState();
    final cubit = context.read<OnboardingCubit>();
    if (cubit.state.heightUnit.isNotEmpty) {
      _selectedUnit = cubit.state.heightUnit;
    }
    if (cubit.state.height.isNotEmpty) {
      if (_selectedUnit == "ft" && cubit.state.height.contains('-')) {
        final parts = cubit.state.height.split('-');
        _height = int.tryParse(parts[0]);
        if (parts.length > 1) {
          _inches = int.tryParse(parts[1]);
        }
      } else {
        _height = int.tryParse(cubit.state.height);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic bounds based on unit (the cm range is InputLimits').
    final minHeight = _selectedUnit == "ft" ? 1 : InputLimits.heightCmMin.round();
    final maxHeight = _selectedUnit == "ft" ? 8 : InputLimits.heightCmMax.round();

    final error = ProfileRules.heightError(_heightCm);
    final valid = error == null;
    widget.onValidityChange(valid);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Image
        Expanded(
          flex: 1,
          child: Builder(
            builder: (context) {
              final physicalHeight = context.screenHeight + MediaQuery.viewInsetsOf(context).bottom;
              final svgHeight = physicalHeight * 0.35;
              return SvgPicture.asset(
                'assets/icons/height.svg',
                height: svgHeight,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => SizedBox(height: svgHeight),
              );
            }
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        // Inputs
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedUnit == "ft") ...[
              OnboardingNumberField<int>(
                value: _height,
                onValueChange: (val) {
                  setState(() => _height = val);
                  _saveHeight();
                },
                min: minHeight,
                max: maxHeight,
                showButtons: true,
                suffixText: "ft",
                isError: widget.showErrors && !valid,
              ),
              const SizedBox(height: AppDimens.space8),
              OnboardingNumberField<int>(
                value: _inches,
                onValueChange: (val) {
                  setState(() => _inches = val);
                  _saveHeight();
                },
                min: 0,
                max: 11,
                showButtons: true,
                suffixText: "in",
                isError: widget.showErrors && !valid,
              ),
            ] else ...[
              OnboardingNumberField<int>(
                value: _height,
                onValueChange: (val) {
                  setState(() => _height = val);
                  _saveHeight();
                },
                min: minHeight,
                max: maxHeight,
                showButtons: true,
                isError: widget.showErrors && !valid,
              ),
            ],
            if (widget.showErrors && error != null) ...[
              const SizedBox(height: AppDimens.space8),
              SizedBox(
                width: AppDimens.numberFieldWidth * 2,
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.error),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.space8),
            UnitDropdown(
              selectedUnit: _selectedUnit,
              units: const ["cm", "ft"],
              onUnitSelected: (unit) {
                setState(() {
                  if (_selectedUnit != unit) {
                    if (unit == "ft" && _height != null) {
                      final totalInches = (_height! / 2.54).round();
                      _height = (totalInches ~/ 12).clamp(1, 8);
                      _inches = (totalInches % 12).clamp(0, 11);
                    } else if (unit == "cm" && _height != null) {
                      final totalInches = (_height! * 12) + (_inches ?? 0);
                      _height = (totalInches * 2.54).round().clamp(
                        InputLimits.heightCmMin.round(),
                        InputLimits.heightCmMax.round(),
                      );
                      _inches = 0;
                    }
                    _selectedUnit = unit;
                  }
                });
                _saveHeight();
              },
            ),
          ],
        ),
      ],
    );
  }

  /// The entered height in cm, or null while incomplete.
  double? get _heightCm {
    final h = _height;
    if (h == null) return null;
    if (_selectedUnit != "ft") return h.toDouble();
    return (h * 12 + (_inches ?? 0)) * 2.54;
  }

  void _saveHeight() {
    // Out-of-range values stay on screen (with an error) but aren't saved.
    if (_height != null && ProfileRules.heightError(_heightCm) == null) {
      final heightStr = _selectedUnit == "ft" ? "$_height-${_inches ?? 0}" : _height.toString();
      context.read<OnboardingCubit>().updateHeight(heightStr, _selectedUnit);
    }
  }
}
