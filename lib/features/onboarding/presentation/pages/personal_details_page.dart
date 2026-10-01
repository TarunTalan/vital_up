import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/profile/presentation/widgets/username_input.dart';
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

  final _usernameService = sl<UsernameService>();

  /// Set only for users who still have a generated username (Google
  /// sign-up); they must choose one before continuing.
  UsernameInput? _username;
  bool _savingUsername = false;
  String? _usernameSaveError;

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
    _loadUsernameStatus();
  }

  /// If this can't load (offline), the step continues without the field
  /// and the home screen asks for the username later.
  Future<void> _loadUsernameStatus() async {
    try {
      final status = await _usernameService.fetchStatus();
      if (!mounted || status == null || status.confirmed) return;
      setState(() {
        _username = UsernameInput(_usernameService, initial: status.username)
          ..addListener(_onUsernameChanged);
      });
    } catch (e) {
      debugPrint('Username status failed to load: $e');
    }
  }

  void _onUsernameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _username?.dispose();
    super.dispose();
  }

  /// Saves the chosen username. Returns false (showing why) if it failed.
  Future<bool> _saveUsername() async {
    final input = _username;
    if (input == null) return true;
    input.touch();
    if (!input.canSubmit) return false;
    setState(() {
      _savingUsername = true;
      _usernameSaveError = null;
    });
    try {
      await _usernameService.setUsername(input.text);
      return true;
    } on UsernameException catch (e) {
      if (e.taken) input.markTaken();
      if (mounted) setState(() => _usernameSaveError = e.message);
      return false;
    } catch (e) {
      debugPrint('Save username failed: $e');
      if (mounted) {
        setState(
          () => _usernameSaveError = "Couldn't save your username. Try again.",
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
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
    final v = context.vColors;
    final errorColor = context.colors.error;
    final nameError = _showErrors && _nameError() != null;
    final age = _calculateAge();
    final dobError = _showErrors && (_dob.isEmpty || age == null || age < 13);
    final genderError = _showErrors &&
        (_gender.toLowerCase() != "male" && _gender.toLowerCase() != "female");

    return OnboardingLayout(
      step: 1,
      onBack: () {
        setState(() => _showErrors = false);
        context.goNamed('login');
      },
      onNext: () async {
        if (_savingUsername) return;
        final usernameReady = _username?.canSubmit ?? true;
        if (!_isValid() || !usernameReady) {
          _username?.touch();
          setState(() {
            _showErrors = true;
          });
          return;
        }
        if (!await _saveUsername() || !context.mounted) return;
        context.read<OnboardingCubit>().setCurrentStep('height');
        context.goNamed('health-height');
      },
      onSkip: () {
        setState(() => _showErrors = false);
        context.goNamed('health-height');
      },
      title: "About you",
      nextEnabled: !_savingUsername,
      showSkip: false,
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_username case final username?) ...[
            OnboardingTextField(
              label: "Username",
              value: username.text,
              maxLength: UsernameService.maxLength,
              onChange: (val) {
                username.text = val;
                if (_usernameSaveError != null) {
                  setState(() => _usernameSaveError = null);
                }
              },
              placeholder: "Choose a username",
              isError: username.isError,
              showErrorText: false,
            ),
            const SizedBox(height: AppDimens.inputLabelGap),
            if (_usernameSaveError != null)
              Text(
                _usernameSaveError!,
                style: context.text.bodyLarge?.copyWith(color: errorColor),
              )
            else
              UsernameHint(input: username),
            const SizedBox(height: AppDimens.space32),
          ],
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
            isError: nameError,
            showErrorText: false,
          ),
          const SizedBox(height: AppDimens.inputLabelGap),
          Text(
            nameError
                ? _nameError()!
                : "This will appear in your profile and reports.",
            style: context.text.bodyLarge?.copyWith(
              color: nameError ? errorColor : v.grayText,
            ),
          ),

          const SizedBox(height: AppDimens.space32),

          OnboardingDateField(
            label: "Date of Birth",
            value: _formatWithSlashes(_dob),
            placeholder: "DD/MM/YYYY",
            onClick: () {
              setState(() => _showErrors = false);
              _selectDate(context);
            },
            isError: dobError,
          ),
          const SizedBox(height: AppDimens.inputLabelGap),
          Text(
            _showErrors && _dob.isEmpty
                ? "Date of Birth is required"
                : (_showErrors && _dob.isNotEmpty && (age == null || age < 13)
                    ? "You must be at least 13 years old"
                    : (age != null
                        ? "Age: $age"
                        : "Enter your DOB in DD/MM/YYYY format")),
            style: context.text.bodyLarge?.copyWith(
              color: dobError
                  ? errorColor
                  : (age != null ? v.preText : v.grayText),
            ),
          ),

          const SizedBox(height: AppDimens.space32),

          Text("Gender", style: context.text.titleSmall),
          const SizedBox(height: AppDimens.inputLabelGap),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
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
              ),
              SizedBox(width: context.w(AppDimens.space32)),
              Expanded(
                child: _GenderButton(
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
              ),
            ],
          ),
          const SizedBox(height: AppDimens.inputLabelGap),
          Text(
            genderError
                ? "Please select your gender"
                : "This helps us personalize insights.",
            style: context.text.bodyMedium?.copyWith(
              color: genderError ? errorColor : v.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma gender tile: 100dp glass tile; selected tints with the gender accent.
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
    final v = context.vColors;
    final accent = gender == "male" ? AppColors.genderMale : AppColors.genderFemale;
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    final iconSize = isSelected ? AppDimens.iconXl : AppDimens.space40;

    return Semantics(
      button: true,
      selected: isSelected,
      label: gender,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: AppDimens.choiceTileHeight,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: isSelected ? null : v.glassFill,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.3, 1.0],
                  colors: [
                    accent.withValues(alpha: 0.13),
                    accent.withValues(alpha: 0.45),
                  ],
                )
              : null,
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.27) : v.glassBorder!,
            width: AppDimens.borderThin,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onClick,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  gender == "male" ? 'assets/icons/gender_male.svg' : 'assets/icons/gender_female.svg',
                  width: iconSize,
                  height: iconSize,
                  placeholderBuilder: (BuildContext context) => Icon(
                    gender == "male" ? Icons.male : Icons.female,
                    size: iconSize,
                    color: accent,
                  ),
                ),
                const SizedBox(height: AppDimens.space8),
                Text(
                  gender == "male" ? "Male" : "Female",
                  style: context.text.bodyLarge?.copyWith(
                    color: isSelected ? context.colors.onSurface : context.vColors.grayText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
