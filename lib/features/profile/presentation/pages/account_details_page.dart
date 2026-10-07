import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/account/data/data_export_service.dart';
import 'package:vital_up/features/account/presentation/delete_account_sheet.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/profile/presentation/widgets/profile_photo_sheet.dart';
import 'package:vital_up/features/profile/presentation/widgets/username_input.dart';

/// Name, username, date of birth, gender and photo, the sign-in email, and
/// exporting or deleting your data.
class AccountDetailsPage extends StatelessWidget {
  const AccountDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final header = const AppPageHeader(
      title: 'Account details',
      subtitle: 'How you appear in VitalUp',
    );
    return BlocBuilder<ProfileCubit, ProfileState>(
      // Swap between the loader and the form only when a profile appears or
      // goes; a failed save keeps the form (and its edits) on screen.
      buildWhen: (prev, next) => next is ProfileError
          ? prev.shownProfile == null
          : (prev.shownProfile == null) != (next.shownProfile == null),
      builder: (context, state) {
        final profile = state.shownProfile ?? cubit.currentProfile;
        if (profile == null) {
          return AppScaffold(
            header: header,
            body: Padding(
              padding: const EdgeInsets.only(top: AppDimens.space48),
              child: state is ProfileError
                  ? LoadErrorView(
                      onRetry: () => cubit.loadProfile(forceRefresh: true),
                    )
                  : const Center(child: VitalUpLoader()),
            ),
          );
        }
        return _AccountForm(profile: profile, header: header);
      },
    );
  }
}

class _AccountForm extends StatefulWidget {
  final ProfileEntity profile;
  final Widget header;

  const _AccountForm({required this.profile, required this.header});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late ProfileEntity _saved = widget.profile;
  late final _name = TextEditingController(text: _saved.fullName);
  late final _usernameController = TextEditingController(
    text: _saved.username,
  );
  late final _username = UsernameInput(sl<UsernameService>());
  late final _dob = TextEditingController(text: _formatDob(_saved.dob));
  late final _email = TextEditingController(text: _saved.email);
  late String _gender = _saved.gender.toLowerCase();
  bool _saving = false;
  bool _exporting = false;
  String? _usernameError;

  static const _genders = ['male', 'female'];

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _dob.addListener(_changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _usernameController.dispose();
    _username.dispose();
    _dob.dispose();
    _email.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// "ddMMyyyy" → "14 Feb 1997".
  static String _formatDob(String dob) {
    final date = _parseDob(dob);
    return date == null ? '' : DateFormat('d MMM yyyy').format(date);
  }

  static DateTime? _parseDob(String dob) {
    if (dob.length != 8) return null;
    final d = int.tryParse(dob.substring(0, 2));
    final m = int.tryParse(dob.substring(2, 4));
    final y = int.tryParse(dob.substring(4));
    return d == null || m == null || y == null ? null : DateTime(y, m, d);
  }

  DateTime? _pickedDob;

  String get _dobRaw => _pickedDob != null
      ? DateFormat('ddMMyyyy').format(_pickedDob!)
      : _saved.dob;

  bool get _usernameChanged =>
      _usernameController.text.trim() != _saved.username;

  bool get _dirty =>
      _name.text.trim() != _saved.fullName ||
      _usernameChanged ||
      _dobRaw != _saved.dob ||
      _gender != _saved.gender.toLowerCase();

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDob ?? _parseDob(_saved.dob) ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    _pickedDob = picked;
    _dob.text = DateFormat('d MMM yyyy').format(picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<ProfileCubit>();
    var username = _saved.username;

    setState(() => _saving = true);
    if (_usernameChanged) {
      _username.touch();
      if (!_username.canSubmit) {
        setState(() => _saving = false);
        return;
      }
      try {
        username = await sl<UsernameService>().setUsername(_username.text);
      } on UsernameException catch (e) {
        if (e.taken) _username.markTaken();
        if (mounted) {
          setState(() {
            _saving = false;
            _usernameError = e.message;
          });
        }
        return;
      } catch (e) {
        debugPrint('Save username failed: $e');
        if (mounted) {
          setState(() {
            _saving = false;
            _usernameError = "Couldn't save your username. Try again.";
          });
        }
        return;
      }
    }

    await cubit.updateProfile(
      (cubit.currentProfile ?? _saved).copyWith(
        fullName: _name.text.trim(),
        username: username,
        dob: _dobRaw,
        gender: _gender,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final error = await sl<DataExportService>().exportAndShare();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (error != null) showErrorSnackBar(context, error);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showSmoothDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("Your edits to account details won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final v = context.vColors;

    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileSaveSuccess) {
          setState(() {
            _saved = state.updatedProfile;
            _pickedDob = null;
          });
          showSuccessSnackBar(context, 'Account details saved');
        } else if (state is ProfileError) {
          showErrorSnackBar(context, state.message);
        } else if (state is ProfilePhotoUpdated) {
          showSuccessSnackBar(
            context,
            state.removed ? 'Profile photo removed' : 'Profile photo updated',
          );
        } else if (state is ProfilePhotoFailed) {
          showErrorSnackBar(context, state.message);
        }
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await _confirmDiscard()) navigator.pop();
        },
        child: AppScaffold(
          header: widget.header,
          bottomBar: AppPrimaryButton(
            label: 'Save changes',
            enabled: _dirty,
            isLoading: _saving,
            onTap: _save,
          ),
          body: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, state) {
                    final profile = cubit.currentProfile ?? _saved;
                    void openPhoto() =>
                        showProfilePhotoOptions(context, cubit, profile);
                    return Row(
                      children: [
                        ProfileAvatar(
                          profile: profile,
                          uploading: state is ProfilePhotoUpdating,
                          onTap: openPhoto,
                        ),
                        const SizedBox(width: AppDimens.space16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile photo',
                                style: context.text.titleSmall,
                              ),
                              TextButton(
                                onPressed: openPhoto,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Change photo'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppDimens.sectionGap),

                const AppSectionHeader('Personal'),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  prefixIcon: Icons.badge_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value.trim().isEmpty) return 'Enter your name';
                    if (value.trim().length < 2) {
                      return 'Use at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.space16),
                ListenableBuilder(
                  listenable: _username,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _usernameController,
                        label: 'Username',
                        prefixIcon: Icons.alternate_email_rounded,
                        inputFormatters: usernameInputFormatters,
                        error: _usernameChanged && _username.isError
                            ? ''
                            : null,
                        onChanged: (value) {
                          _username.text = value;
                          setState(() => _usernameError = null);
                        },
                      ),
                      if (_usernameChanged || _usernameError != null) ...[
                        const SizedBox(height: AppDimens.inputLabelGap),
                        if (_usernameError != null)
                          Text(
                            _usernameError!,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.error,
                            ),
                          )
                        else
                          UsernameHint(input: _username),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.space16),
                AppTextField(
                  controller: _dob,
                  label: 'Date of birth',
                  prefixIcon: Icons.calendar_month_rounded,
                  readOnly: true,
                  onTap: _pickDob,
                  suffix: const Icon(Icons.arrow_drop_down_rounded),
                  validator: (value) =>
                      value.trim().isEmpty ? 'Add your date of birth' : null,
                ),
                const SizedBox(height: AppDimens.space16),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimens.inputLabelGap,
                  ),
                  child: Text('Gender', style: context.text.titleSmall),
                ),
                AppSegmentedControl<String>(
                  values: _genders,
                  selected: _gender,
                  label: displayGender,
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: AppDimens.sectionGap),

                const AppSectionHeader('Sign-in'),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  enabled: false,
                  suffix: Icon(Icons.lock_outline_rounded, color: v.grayText),
                ),
                const SizedBox(height: AppDimens.space8),
                const AppInfoNote(
                  message:
                      'You sign in with this email. Contact support to change it.',
                ),
                const SizedBox(height: AppDimens.sectionGap),

                AppListGroup(
                  title: 'Your data',
                  children: [
                    AppListTile(
                      icon: Icons.download_rounded,
                      title: 'Export my data',
                      subtitle: 'Logs, workouts and profile as CSV / JSON',
                      trailing: _exporting
                          ? SizedBox.square(
                              dimension: AppDimens.iconMd,
                              child: CircularProgressIndicator(
                                strokeWidth: AppDimens.borderThick,
                                color: context.colors.primary,
                              ),
                            )
                          : null,
                      onTap: _exporting ? null : _export,
                    ),
                    AppListTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete account',
                      subtitle: 'Permanently remove your account and data',
                      destructive: true,
                      onTap: () => showDeleteAccountSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
