import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/utils/onboarding_components.dart';

class InfoAndPermissionPage extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const InfoAndPermissionPage({
    super.key,
    this.onNext,
    this.onBack,
    this.onSkip,
  });

  @override
  State<InfoAndPermissionPage> createState() => _InfoAndPermissionPageState();
}

class _InfoAndPermissionPageState extends State<InfoAndPermissionPage> {
  bool shareAnonymous = false;
  bool healthReminders = false;
  bool syncDevices = false;
  bool showErrors = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingData>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == SubmissionStatus.success) {
          context.go('/dashboard');
        } else if (state.status == SubmissionStatus.error) {
          showErrorSnackBar(context, state.errorMessage ?? 'An error occurred');
        }
      },
      builder: (context, state) {
        final isSubmitting = state.status == SubmissionStatus.submitting;
        return OnboardingLayout(
          step: 7,
          handleSystemBack: false,
          onBack: widget.onBack ?? () {},
          onSkip: widget.onSkip ?? () {},
          nextLabel: isSubmitting ? "Saving..." : "Done",
          onNext: isSubmitting
              ? () {}
              : () {
                  if (healthReminders) {
                    sl<RemindersService>().enableStarterSet();
                  }
                  context.read<OnboardingCubit>().submitOnboardingDataToBackend();
                },
          title: "Data privacy",
          subtitle: "We only collect what's needed.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoBox(
                context: context,
                title: "What we collect",
                items: [
                  _InfoItem('assets/icons/Stethoscope.svg', Icons.medical_services, "Health details you share"),
                  _InfoItem('assets/icons/Watch.svg', Icons.watch, "Data from connected devices"),
                  _InfoItem('assets/icons/settings.svg', Icons.settings, "Your app preferences"),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),
              _buildInfoBox(
                context: context,
                title: "What we do NOT do",
                items: [
                  _InfoItem('assets/icons/tick.svg', Icons.check, "Never sell your data", iconSize: AppDimens.space12),
                  _InfoItem('assets/icons/tick.svg', Icons.check, "Never post without asking", iconSize: AppDimens.space12),
                  _InfoItem('assets/icons/tick.svg', Icons.check, "Never contact anyone without consent", iconSize: AppDimens.space12),
                ],
              ),
              const SizedBox(height: AppDimens.sectionGap),
              _buildChoicesBox(context),
              const SizedBox(height: AppDimens.sectionGap),
              const NoteRow(
                text: "We collect nothing without your permission.",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBox({
    required BuildContext context,
    required String title,
    required List<_InfoItem> items,
  }) {
    final iconColor = context.vColors.preText!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.cardInnerGap),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.space8),
            Row(
              children: [
                Container(
                  width: AppDimens.space32,
                  height: AppDimens.space32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.vColors.primaryFill,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    items[i].iconPath,
                    width: items[i].iconSize,
                    height: items[i].iconSize,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    placeholderBuilder: (_) => Icon(
                      items[i].fallbackIcon,
                      size: items[i].iconSize,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.space16),
                Expanded(
                  child: Text(items[i].text, style: context.text.bodyLarge),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoicesBox(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      tint: showErrors ? context.vColors.errorFill : null,
      borderColor: showErrors ? colors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your choices", style: context.text.headlineSmall),
          const SizedBox(height: AppDimens.cardInnerGap),
          _ToggleRow(
            title: "Share anonymous data",
            subtitle: "Help improve the app for everyone",
            checked: shareAnonymous,
            addTopDivider: false,
            onChanged: (val) {
              setState(() {
                shareAnonymous = val;
                showErrors = false;
              });
            },
          ),
          _ToggleRow(
            title: "Health reminders",
            subtitle: "Get gentle wellness notifications",
            checked: healthReminders,
            onChanged: (val) {
              setState(() {
                healthReminders = val;
                showErrors = false;
              });
            },
          ),
          _ToggleRow(
            title: "Sync with connected devices",
            subtitle: "Auto-update from your wearables",
            checked: syncDevices,
            onChanged: (val) {
              setState(() {
                syncDevices = val;
                showErrors = false;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String iconPath;
  final IconData fallbackIcon;
  final String text;
  final double iconSize;

  _InfoItem(this.iconPath, this.fallbackIcon, this.text, {this.iconSize = AppDimens.iconXs});
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool addTopDivider;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
    this.addTopDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return Column(
      children: [
        if (addTopDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.space8),
            child: Divider(),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppDimens.space8),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(color: v.grayText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.space16),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: checked,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  onChanged(val);
                },
                activeThumbColor: AppColors.white,
                activeTrackColor: context.colors.primary,
                inactiveThumbColor: AppColors.white,
                inactiveTrackColor: v.secondaryButtonBorder,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
