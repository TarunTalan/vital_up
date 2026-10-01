import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:vital_up/features/reminders/presentation/widgets/reminder_editor_sheet.dart';
import 'package:vital_up/features/reminders/presentation/widgets/reminder_style.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  Future<void> _edit(
    BuildContext context,
    Reminder reminder, {
    bool isNew = false,
  }) async {
    final cubit = context.read<RemindersCubit>();
    final result = await showReminderEditor(
      context,
      reminder: reminder,
      isNew: isNew,
    );
    switch (result) {
      case ReminderSaved(:final reminder):
        await cubit.saveReminder(reminder);
      case ReminderDeleted():
        await cubit.delete(reminder);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'Reminders'),
      scrollable: false,
      padBody: false,
      body: BlocConsumer<RemindersCubit, RemindersState>(
        listenWhen: (prev, next) => next.messageId != prev.messageId,
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.message!))),
        builder: (context, state) {
          if (state.loading) return const Center(child: VitalUpLoader());
          final cubit = context.read<RemindersCubit>();
          final custom = state.custom;
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              AppDimens.sectionGap,
              context.gutter,
              AppDimens.sectionGap + context.safePadding.bottom,
            ),
            children: [
              if (!state.notificationsEnabled)
                const _Banner(
                  message:
                      'Notifications are off in Settings, so reminders '
                      "won't be delivered.",
                )
              else if (state.permissionDenied)
                _Banner(
                  message:
                      'Notifications are blocked for VitalUp. Allow them in '
                      'your phone settings to get reminders.',
                  actionLabel: 'Open phone settings',
                  onAction: () => openAppSettings(),
                ),
              _Section(
                title: 'Smart reminders',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.space8,
                    ),
                    child: Row(
                      children: [
                        const AppIconBadge(
                          icon: Icon(Icons.auto_awesome_rounded),
                        ),
                        const SizedBox(width: AppDimens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Skip when done',
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: AppDimens.space2),
                              Text(
                                'No more water reminders once you hit your '
                                "goal, or meal reminders once it's logged.",
                                style: context.text.bodySmall?.copyWith(
                                  color: context.vColors.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimens.space8),
                        Switch(
                          value: state.smartSkip,
                          onChanged: cubit.setSmartSkip,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _Section(
                title: 'Healthy habits',
                children: [
                  for (final r in state.presets)
                    _ReminderRow(
                      reminder: r,
                      onTap: () => _edit(context, r),
                      onToggle: (on) => cubit.toggle(r, on),
                    ),
                ],
              ),
              if (custom.isNotEmpty)
                _Section(
                  title: 'Your reminders',
                  children: [
                    for (final r in custom)
                      _ReminderRow(
                        reminder: r,
                        onTap: () => _edit(context, r),
                        onToggle: (on) => cubit.toggle(r, on),
                      ),
                  ],
                ),
              AppPrimaryButton(
                label: 'Add reminder',
                leadingIcon: const Icon(Icons.add_rounded),
                onTap: () => _edit(context, cubit.draftCustom(), isNew: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Banner({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInfoNote(message: message, icon: Icons.notifications_off_outlined),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Caption + card, like the Settings sections.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCaption(title),
          const SizedBox(height: AppDimens.space8),
          AppCard(
            width: double.infinity,
            padding: AppDimens.cardPaddingCompact,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: context.vColors.divider,
                      height: AppDimens.borderThin,
                      thickness: AppDimens.borderThin,
                      indent: AppDimens.iconBadge + AppDimens.space12,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _ReminderRow({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final kind = reminder.kind;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
        child: Row(
          children: [
            AppIconBadge(icon: Icon(kind.icon), color: kind.color),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.title, style: context.text.titleSmall),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    reminderSummary(reminder),
                    style: context.text.bodySmall?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            Switch(value: reminder.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
