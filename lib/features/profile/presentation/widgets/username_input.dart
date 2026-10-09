import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';

enum UsernameCheck { idle, invalid, checking, taken, available, unknown }

/// Text, rules and live availability for a username field. Shared by the
/// onboarding personal-details step and the home-screen prompt.
class UsernameInput extends ChangeNotifier {
  final UsernameService _service;

  UsernameInput(this._service, {String initial = ''}) : _text = initial {
    if (initial.isNotEmpty) _validate();
  }

  static const _debounce = Duration(milliseconds: 400);

  String _text;
  UsernameCheck _check = UsernameCheck.idle;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  String get text => _text;
  UsernameCheck get check => _check;

  /// Good to save. When availability couldn't be checked (offline), the
  /// server still validates on save.
  bool get canSubmit =>
      _check == UsernameCheck.available || _check == UsernameCheck.unknown;

  /// Shown under the field; [isError] colours it.
  String get message => switch (_check) {
    UsernameCheck.idle => 'This is how friends find and add you.',
    UsernameCheck.invalid => UsernameService.formatError(_text)!,
    UsernameCheck.checking => 'Checking…',
    UsernameCheck.taken => 'That username is taken',
    UsernameCheck.available => '@${_text.trim()} is available',
    UsernameCheck.unknown => "Couldn't check right now. We'll check when you save.",
  };

  bool get isError =>
      _check == UsernameCheck.invalid || _check == UsernameCheck.taken;

  set text(String value) {
    if (value == _text) return;
    _text = value;
    _validate();
  }

  /// The server said it's taken on save (someone got it after the check).
  void markTaken() {
    _check = UsernameCheck.taken;
    notifyListeners();
  }

  /// Shows rule errors for an empty field when the user tries to continue.
  void touch() {
    if (_check == UsernameCheck.idle) {
      _check = UsernameCheck.invalid;
      notifyListeners();
    }
  }

  void _validate() {
    _timer?.cancel();
    final generation = ++_generation;
    if (UsernameService.formatError(_text) != null) {
      _check = _text.isEmpty ? UsernameCheck.idle : UsernameCheck.invalid;
      notifyListeners();
      return;
    }
    _check = UsernameCheck.checking;
    notifyListeners();
    _timer = Timer(_debounce, () async {
      UsernameCheck result;
      try {
        result = await _service.isAvailable(_text)
            ? UsernameCheck.available
            : UsernameCheck.taken;
      } catch (e) {
        debugPrint('Username availability check failed: $e');
        result = UsernameCheck.unknown;
      }
      // A newer keystroke started another check, or the page closed.
      if (_disposed || generation != _generation) return;
      _check = result;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Characters a username can't contain are dropped as they're typed.
final usernameInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._]')),
  LengthLimitingTextInputFormatter(UsernameService.maxLength),
];

/// Helper line under a username field.
class UsernameHint extends StatelessWidget {
  final UsernameInput input;

  const UsernameHint({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final color = input.isError
        ? context.colors.error
        : input.check == UsernameCheck.available
        ? v.success
        : v.grayText;
    return Text(
      input.message,
      style: context.text.bodyMedium?.copyWith(color: color),
    );
  }
}

/// Asks a user with a generated username (Google sign-up past onboarding)
/// to choose one. Can't be dismissed until a username is saved.
Future<void> showUsernamePrompt(
  BuildContext context, {
  required UsernameService service,
  required String suggestion,
}) => showSmoothDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UsernamePrompt(service: service, suggestion: suggestion),
);

class _UsernamePrompt extends StatefulWidget {
  final UsernameService service;
  final String suggestion;

  const _UsernamePrompt({required this.service, required this.suggestion});

  @override
  State<_UsernamePrompt> createState() => _UsernamePromptState();
}

class _UsernamePromptState extends State<_UsernamePrompt> {
  late final _input = UsernameInput(widget.service, initial: widget.suggestion);
  late final _controller = TextEditingController(text: widget.suggestion);
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _input.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _input.touch();
    if (!_input.canSubmit || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.service.setUsername(_input.text);
      if (mounted) Navigator.of(context).pop();
    } on UsernameException catch (e) {
      if (e.taken) _input.markTaken();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.message;
      });
    } catch (e) {
      debugPrint('Save username failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = "Couldn't save your username. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Choose your username'),
        content: ListenableBuilder(
          listenable: _input,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Friends use it to find and add you. You can keep the '
                'suggestion or pick your own.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
              const SizedBox(height: AppDimens.space16),
              AppTextField(
                controller: _controller,
                hint: 'username',
                prefixIcon: Icons.alternate_email_rounded,
                inputFormatters: usernameInputFormatters,
                textInputAction: TextInputAction.done,
                error: _input.isError ? '' : null,
                onChanged: (value) {
                  _input.text = value;
                  if (_saveError != null) setState(() => _saveError = null);
                },
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppDimens.inputLabelGap),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                )
              else
                UsernameHint(input: _input),
              const SizedBox(height: AppDimens.space20),
              AppPrimaryButton(
                label: 'Save username',
                isLoading: _saving,
                enabled: _input.canSubmit,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
