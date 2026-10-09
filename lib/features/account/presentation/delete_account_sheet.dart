import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/account/data/account_service.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';

/// Asks the user to type DELETE, then deletes the account. On success the
/// app signs out (the dashboard's auth listener returns to onboarding).
Future<void> showDeleteAccountSheet(BuildContext context) async {
  // Not dismissible by tap or drag: closing mid-delete would lose the
  // result and leave the app signed in to a deleted account.
  final deleted = await showAppBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _DeleteAccountSheet(),
  );
  if (deleted == true && context.mounted) {
    context.read<AuthCubit>().accountDeleted();
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _confirmWord = 'DELETE';

  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _confirmed => _confirm.text.trim().toUpperCase() == _confirmWord;

  Future<void> _delete() async {
    if (_deleting || !_confirmed) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final error = await sl<AccountService>().deleteAccount();
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _deleting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = context.colors.error;
    return PopScope(
      canPop: !_deleting,
      child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delete account',
                    style: context.text.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: _deleting ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Divider(
              height: AppDimens.borderThin,
              color: context.vColors.divider,
            ),
            const SizedBox(height: AppDimens.sectionGap),
            Text(
              'This permanently deletes your account and everything in it: '
              'your profile, logs, workouts, points, badges, friends and '
              'notifications. It can\'t be undone.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppDimens.space12),
            const AppInfoNote(
              message:
                  'Deleting your account does not cancel a subscription. '
                  'Cancel it in your App Store or Google Play account first.',
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppTextField(
              label: 'Type $_confirmWord to confirm',
              controller: _confirm,
              hint: _confirmWord,
              textCapitalization: TextCapitalization.characters,
              maxLength: InputLimits.usernameMax,
              enabled: !_deleting,
              error: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(
              label: 'Delete my account',
              isLoading: _deleting,
              enabled: _confirmed && !_deleting,
              containerColor: error,
              borderColor: error,
              onTap: _delete,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
