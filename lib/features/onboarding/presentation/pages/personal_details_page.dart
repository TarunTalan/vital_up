import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/widgets/onboarding_widgets.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';
import 'package:vital_up/features/profile/presentation/widgets/username_input.dart';

/// Step 1, "About you": username (only for Google sign-ups that still
/// have a generated one), full name, date of birth and gender. Required:
/// every estimate after it depends on them.
class PersonalDetailsStep extends StatefulWidget {
  /// Where the cascade of this step's fields starts (after the intro).
  final int revealFrom;

  const PersonalDetailsStep({super.key, this.revealFrom = 3});

  @override
  State<PersonalDetailsStep> createState() => _PersonalDetailsStepState();
}

class _PersonalDetailsStepState extends State<PersonalDetailsStep>
    with OnboardingStepState {
  late final TextEditingController _name;
  late final TextEditingController _dobText;
  String _dob = '';
  String _gender = '';
  bool _showErrors = false;

  final _usernameService = sl<UsernameService>();

  /// Set only for users who still have a generated username (Google
  /// sign-up); they must choose one before continuing.
  UsernameInput? _username;
  final _usernameText = TextEditingController();
  String? _usernameSaveError;

  @override
  void initState() {
    super.initState();
    final state = context.read<OnboardingCubit>().state;
    _name = TextEditingController(text: state.fullName);
    _dob = state.dob;
    _dobText = TextEditingController(text: _formatDob(_dob));
    _gender = state.gender.toLowerCase();
    _loadUsernameStatus();
  }

  /// If this can't load (offline), the step continues without the field
  /// and the home screen asks for the username later.
  Future<void> _loadUsernameStatus() async {
    try {
      final status = await _usernameService.fetchStatus();
      if (!mounted || status == null || status.confirmed) return;
      setState(() {
        _usernameText.text = status.username;
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
    _name.dispose();
    _dobText.dispose();
    _usernameText.dispose();
    _username?.dispose();
    super.dispose();
  }

  static bool _isGender(String g) => g == 'male' || g == 'female';

  String? get _nameError => ProfileRules.nameError(_name.text);
  String? get _dobError => ProfileRules.dobError(_dob);

  /// "24/06/1996" from the stored "24061996".
  static String _formatDob(String dob) {
    final date = ProfileRules.parseDob(dob);
    if (date == null) return '';
    return '${dob.substring(0, 2)}/${dob.substring(2, 4)}/${dob.substring(4)}';
  }

  @override
  Future<bool> submit() async {
    final usernameReady = _username?.canSubmit ?? true;
    if (_nameError != null ||
        _dobError != null ||
        !_isGender(_gender) ||
        !usernameReady) {
      _username?.touch();
      setState(() => _showErrors = true);
      return false;
    }
    await context.read<OnboardingCubit>().updateFullName(
      ProfileRules.cleanName(_name.text),
    );
    return _saveUsername();
  }

  /// Saves the chosen username. Returns false (showing why) if it failed.
  Future<bool> _saveUsername() async {
    final input = _username;
    if (input == null) return true;
    input.touch();
    if (!input.canSubmit) return false;
    setState(() => _usernameSaveError = null);
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
    }
  }

  Future<void> _pickDob() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    // The picker only offers supported ages (InputLimits.ageMin to ageMax);
    // the initial date must sit inside that range or the picker asserts.
    final saved = ProfileRules.parseDob(_dob);
    final picked = await showDatePicker(
      context: context,
      initialDate: ProfileRules.clampDob(
        saved ?? DateTime(now.year - 25, now.month, 1),
        now,
      ),
      firstDate: ProfileRules.firstDob(now),
      lastDate: ProfileRules.lastDob(now),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked == null || !mounted) return;
    final dob = ProfileRules.formatDob(picked);
    setState(() {
      _dob = dob;
      _dobText.text = _formatDob(dob);
    });
    context.read<OnboardingCubit>().updateDob(dob);
  }

  void _pickGender(String gender) {
    setState(() => _gender = gender);
    context.read<OnboardingCubit>().updateGender(gender);
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    final nameError = _showErrors ? _nameError : null;
    final dobError = _showErrors ? _dobError : null;
    final age = ProfileRules.ageFromDob(_dob);
    var i = widget.revealFrom;

    Widget helper(String text) => Padding(
      padding: const EdgeInsets.only(top: AppDimens.inputLabelGap),
      child: Text(text, style: context.text.bodyMedium?.copyWith(color: grey)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_username case final username?) ...[
          OnboardingReveal(
            index: i++,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Username',
                  controller: _usernameText,
                  hint: 'Choose a username',
                  maxLength: UsernameService.maxLength,
                  prefixIcon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  error:
                      _usernameSaveError ??
                      (username.isError ? username.message : null),
                  onChanged: (value) {
                    username.text = value;
                    if (_usernameSaveError != null) {
                      setState(() => _usernameSaveError = null);
                    }
                  },
                ),
                if (_usernameSaveError == null && !username.isError)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimens.inputLabelGap,
                    ),
                    child: UsernameHint(input: username),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sectionGap),
        ],
        OnboardingReveal(
          index: i++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Full name',
                controller: _name,
                hint: 'Your full name',
                maxLength: InputLimits.name,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                error: nameError,
                onChanged: (value) {
                  context.read<OnboardingCubit>().updateFullName(
                    ProfileRules.cleanName(value),
                  );
                  if (nameError != null) setState(() => _showErrors = false);
                },
              ),
              if (nameError == null)
                helper('Shown on your profile and health reports.'),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Date of birth',
                controller: _dobText,
                hint: 'DD/MM/YYYY',
                readOnly: true,
                prefixIcon: Icons.cake_outlined,
                suffix: Icon(
                  Icons.calendar_month_rounded,
                  size: AppDimens.iconMd,
                  color: grey,
                ),
                error: dobError,
                onTap: _pickDob,
              ),
              if (dobError == null)
                helper(
                  age != null
                      ? 'You are $age. This sets your calorie and sleep needs.'
                      : 'Your age sets your calorie and sleep needs.',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sectionGap),
        OnboardingReveal(
          index: i++,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gender', style: context.text.titleSmall),
              const SizedBox(height: AppDimens.inputLabelGap),
              Row(
                children: [
                  for (final gender in const ['male', 'female']) ...[
                    if (gender == 'female')
                      const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: _GenderTile(
                        gender: gender,
                        selected: _gender == gender,
                        onTap: () => _pickGender(gender),
                      ),
                    ),
                  ],
                ],
              ),
              OnboardingErrorText(
                _showErrors && !_isGender(_gender)
                    ? 'Choose one to continue.'
                    : null,
              ),
              if (!(_showErrors && !_isGender(_gender)))
                helper('Used for your energy needs. Never shown to others.'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Male / female tile: the figure grows a little and the tile takes the
/// gender's tint when chosen, with the round check in its corner.
class _GenderTile extends StatefulWidget {
  final String gender;
  final bool selected;
  final VoidCallback onTap;

  const _GenderTile({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_GenderTile> createState() => _GenderTileState();
}

class _GenderTileState extends State<_GenderTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final male = widget.gender == 'male';
    final accent = male ? AppColors.genderMale : AppColors.genderFemale;
    final label = male ? 'Male' : 'Female';
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minHeight: AppDimens.choiceTileHeight,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: AppDimens.tintAlpha)
                : v.glassFill,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: AppDimens.tintBorderAlpha)
                  : v.glassBorder!,
              width: AppDimens.borderThin,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap();
              },
              onHighlightChanged: (down) => setState(() => _pressed = down),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.space16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.15 : 1,
                            duration: AppDurations.bounce,
                            curve: Curves.easeOutBack,
                            child: SvgPicture.asset(
                              male
                                  ? 'assets/icons/onboarding/gender_male.svg'
                                  : 'assets/icons/onboarding/gender_female.svg',
                              width: AppDimens.iconXl,
                              height: AppDimens.iconXl,
                              placeholderBuilder: (_) => Icon(
                                male
                                    ? Icons.male_rounded
                                    : Icons.female_rounded,
                                size: AppDimens.iconXl,
                                color: context.iconTint(accent),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimens.space8),
                          Text(
                            label,
                            style: context.text.titleSmall?.copyWith(
                              color: selected
                                  ? context.colors.onSurface
                                  : v.grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: AppDimens.space8,
                    end: AppDimens.space8,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: AppDurations.medium,
                      child: OnboardingSelectMark(selected: selected),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
