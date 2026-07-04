import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
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
      title: "How tall are you?",
      subtitle: "Used only to tailor health insights. You can update this anytime.",
      nextEnabled: true,
      child: _HeightContent(
        onValidityChange: (valid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _latestValid = valid;
              });
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
    // Dynamic bounds based on unit
    final minHeight = _selectedUnit == "ft" ? 2 : 20;
    final maxHeight = _selectedUnit == "ft" ? 12 : 250;

    final valid = _height != null;
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
              final physicalHeight = MediaQuery.of(context).size.height + MediaQuery.of(context).viewInsets.bottom;
              final svgHeight = physicalHeight * 0.35;
              return SvgPicture.asset(
                'assets/icons/height.svg',
                height: svgHeight,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => SizedBox(
                  height: svgHeight, 
                  child: Placeholder(fallbackHeight: svgHeight, fallbackWidth: 100),
                ),
              );
            }
          ),
        ),
        const SizedBox(width: OnboardingStyle.controlGap),
        // Inputs
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedUnit == "ft") ...[
              OnboardingNumberField<int>(
                value: _height,
                onValueChange: (val) {
                  final newValue = val ?? minHeight;
                  setState(() => _height = newValue);
                  _saveHeight();
                },
                min: minHeight,
                max: maxHeight,
                showButtons: true,
                suffixText: "ft",
                isError: widget.showErrors && !valid,
              ),
              const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
              OnboardingNumberField<int>(
                value: _inches,
                onValueChange: (val) {
                  final newValue = val ?? 0;
                  setState(() => _inches = newValue);
                  _saveHeight();
                },
                min: 0,
                max: 11,
                showButtons: true,
                suffixText: "in",
                isError: widget.showErrors && _inches == null,
              ),
            ] else ...[
              OnboardingNumberField<int>(
                value: _height,
                onValueChange: (val) {
                  final newValue = val ?? minHeight;
                  setState(() => _height = newValue);
                  _saveHeight();
                },
                min: minHeight,
                max: maxHeight,
                showButtons: true,
                isError: widget.showErrors && !valid,
              ),
            ],
            const SizedBox(height: OnboardingStyle.sectionSpacingSmall),
            UnitDropdown(
              selectedUnit: _selectedUnit,
              units: const ["cm", "ft"],
              onUnitSelected: (unit) {
                setState(() {
                  if (_selectedUnit != unit) {
                    if (unit == "ft" && _height != null) {
                      final totalInches = (_height! / 2.54).round();
                      _height = (totalInches ~/ 12).clamp(2, 12);
                      _inches = (totalInches % 12).clamp(0, 11);
                    } else if (unit == "cm" && _height != null) {
                      final totalInches = (_height! * 12) + (_inches ?? 0);
                      _height = (totalInches * 2.54).round().clamp(20, 250);
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

  void _saveHeight() {
    if (_height != null) {
      final heightStr = _selectedUnit == "ft" ? "$_height-${_inches ?? 0}" : _height.toString();
      context.read<OnboardingCubit>().updateHeight(heightStr, _selectedUnit);
    }
  }
}
