import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/utils/onboarding_components.dart';
import 'dart:math' as math;

class PersonalDetailsPage extends StatefulWidget {
  const PersonalDetailsPage({super.key});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  bool _showErrors = false;

  late TextEditingController _nameController;
  String _dob = '';
  String _gender = '';

  @override
  void initState() {
    super.initState();
    final cubit = context.read<OnboardingCubit>();
    _nameController = TextEditingController(text: cubit.state.fullName);
    _dob = cubit.state.dob;
    _gender = cubit.state.gender;
    
    _nameController.addListener(() {
      context.read<OnboardingCubit>().updateFullName(_nameController.text.trim());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _nameError() {
    final text = _nameController.text.trim();
    if (text.isEmpty) return "Full Name is required";
    if (text.length < 2) return "Must be at least 2 characters";
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(text)) return "Letters and spaces only";
    return null;
  }

  bool _isValid() {
    final age = _calculateAge();
    return _nameError() == null &&
        _dob.isNotEmpty &&
        age != null && age >= 10 &&
        (_gender.toLowerCase() == 'male' || _gender.toLowerCase() == 'female');
  }

  String _formatWithSlashes(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) return '${digits.substring(0, 2)}/${digits.substring(2)}';
    return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4, math.min(8, digits.length))}';
  }

  int? _calculateAge() {
    if (_dob.length == 8) {
       try {
         final day = int.parse(_dob.substring(0, 2));
         final month = int.parse(_dob.substring(2, 4));
         final year = int.parse(_dob.substring(4, 8));
         final dobDate = DateTime(year, month, day);
         final now = DateTime.now();
         int age = now.year - dobDate.year;
         if (now.month < dobDate.month || (now.month == dobDate.month && now.day < dobDate.day)) {
           age--;
         }
         if (age <= 0) return null;
         return age;
       } catch (_) {}
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    DateTime? initialDate;
    if (_dob.length == 8) {
       try {
         final day = int.parse(_dob.substring(0, 2));
         final month = int.parse(_dob.substring(2, 4));
         final year = int.parse(_dob.substring(4, 8));
         initialDate = DateTime(year, month, day);
       } catch (_) {}
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    
    if (picked != null) {
      setState(() {
        final day = picked.day.toString().padLeft(2, '0');
        final month = picked.month.toString().padLeft(2, '0');
        final year = picked.year.toString();
        _dob = '$day$month$year';
        _showErrors = false;
      });
      context.read<OnboardingCubit>().updateDob(_dob);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OnboardingLayout(
      step: 1,
      onBack: () {
        setState(() => _showErrors = false);
        context.goNamed('login');
      },
      onNext: () {
        if (!_isValid()) {
          setState(() {
            _showErrors = true;
          });
        } else {
          context.read<OnboardingCubit>().setCurrentStep('height');
          context.goNamed('health-height');
        }
      },
      onSkip: () {
        setState(() => _showErrors = false);
        context.goNamed('health-height');
      },
      title: "First, let's get to know you",
      nextEnabled: true,
      showSkip: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              OnboardingTextField(
              label: "Full Name",
              value: _nameController.text,
              maxLength: 50,
              onChange: (val) {
                _nameController.text = val;
                if (_showErrors) {
                  setState(() => _showErrors = false);
                }
              },
              placeholder: "Enter your full name",
              isError: _showErrors && _nameError() != null,
              showErrorText: false,
          ),
          Padding(
            padding: const EdgeInsets.only(top: OnboardingStyle.sectionSpacingSmall),
            child: Text(
              _showErrors && _nameError() != null
                  ? _nameError()!
                  : "This will appear in your profile and reports.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _showErrors && _nameError() != null
                    ? Theme.of(context).colorScheme.error
                    : colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: OnboardingStyle.sectionSpacingMedium),

          OnboardingDateField(
            label: "Date of Birth",
            value: _formatWithSlashes(_dob),
            placeholder: "DD/MM/YYYY",
            onClick: () {
              setState(() => _showErrors = false);
              _selectDate(context);
            },
            isError: _showErrors && (_dob.isEmpty || _calculateAge() == null || _calculateAge()! < 13),
          ),
          Padding(
            padding: const EdgeInsets.only(top: OnboardingStyle.sectionSpacingSmall),
            child: Text(
              _showErrors && _dob.isEmpty
                  ? "Date of Birth is required"
                  : (_showErrors && _dob.isNotEmpty && (_calculateAge() == null || _calculateAge()! < 13)
                      ? "You must be at least 13 years old"
                      : (_calculateAge() != null
                          ? "Age: ${_calculateAge()}"
                          : "Enter your date of birth in DD/MM/YYYY format")),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _showErrors && (_dob.isEmpty || (_calculateAge() == null || _calculateAge()! < 13))
                    ? Theme.of(context).colorScheme.error
                    : (_calculateAge() != null
                        ? const Color.fromRGBO(15, 117, 134, 1)
                        : colors.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          ),

          const SizedBox(height: OnboardingStyle.sectionSpacingMedium),

          Text(
            "Gender",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          SizedBox(height: AppTheme.responsiveHeight(context, 6.0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GenderButton(
                gender: "male",
                isSelected: _gender.toLowerCase() == "male",
                onClick: () {
                  setState(() {
                    _gender = "male";
                    _showErrors = false;
                  });
                  context.read<OnboardingCubit>().updateGender("male");
                },
              ),
              _GenderButton(
                gender: "female",
                isSelected: _gender.toLowerCase() == "female",
                onClick: () {
                  setState(() {
                    _gender = "female";
                    _showErrors = false;
                  });
                  context.read<OnboardingCubit>().updateGender("female");
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: OnboardingStyle.sectionSpacingSmall),
            child: Text(
              _showErrors && (_gender.toLowerCase() != "male" && _gender.toLowerCase() != "female")
                  ? "Please select your gender"
                  : "This helps us personalize insights.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _showErrors && (_gender.toLowerCase() != "male" && _gender.toLowerCase() != "female")
                    ? Theme.of(context).colorScheme.error
                    : colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String gender;
  final bool isSelected;
  final VoidCallback onClick;

  const _GenderButton({
    required this.gender,
    this.isSelected = false,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius));

    final boxWidth = OnboardingStyle.numberFieldWidth + OnboardingStyle.sectionSpacingLarge;
    final boxHeight = OnboardingStyle.numberFieldHeight + OnboardingStyle.sectionSpacingLarge;

    return InkWell(
      onTap: onClick,
      customBorder: shape,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30.6, sigmaY: 30.6),
          child: Container(
            width: boxWidth,
            height: boxHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              color: isSelected 
                  ? const Color.fromRGBO(70, 94, 235, 0.13) 
                  : const Color.fromRGBO(186, 186, 186, 0.13),
              border: Border.all(
                color: isSelected 
                    ? const Color.fromRGBO(70, 94, 235, 0.27) 
                    : const Color.fromRGBO(186, 186, 186, 0.27),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(70, 94, 235, 0),
                          Color.fromRGBO(70, 94, 235, 1),
                        ],
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                gender == "male" ? 'assets/icons/gender_male.svg' : 'assets/icons/gender_female.svg',
                width: OnboardingStyle.sectionSpacingLarge,
                height: OnboardingStyle.sectionSpacingLarge,
                placeholderBuilder: (BuildContext context) => Icon(
                  gender == "male" ? Icons.male : Icons.female,
                  size: OnboardingStyle.sectionSpacingLarge,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
