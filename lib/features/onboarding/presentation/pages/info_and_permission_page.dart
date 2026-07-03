import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? 'An error occurred')),
          );
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
        extendBodyBehindAppBar: true,
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(
            top: 16.0,
            bottom: OnboardingStyle.bottomBarPaddingBottom,
          ),
          child: BlocBuilder<OnboardingCubit, OnboardingData>(
            builder: (context, state) {
              return OnboardingBottomBar(
                onSkip: widget.onSkip ?? () {},
                nextLabel: state.status == SubmissionStatus.submitting ? "Saving..." : "Done",
                onNext: state.status == SubmissionStatus.submitting 
                  ? () {} 
                  : () {
                      context.read<OnboardingCubit>().submitOnboardingDataToBackend();
                    },
              );
            },
          ),
        ),
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            // Blur effect
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16.0), // Top margin above the bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                    child: OnboardingTopBar(
                      onBack: widget.onBack ?? () {}, 
                      step: 10,
                    ),
                  ),
                  const SizedBox(height: 16.0), // Padding below top bar to prevent hard clipping on scroll
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: OnboardingStyle.screenHorizontalPadding),
                      children: [
                  const SizedBox(height: 24.0), // Reduced from 40.0 to account for the 16.0 above
                  Text(
                    "Your health data stays with you",
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OnboardingStyle.titleSubtitleSpacing),
                  Text(
                    "We only collect what's needed for your wellness.",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
                  
                  // Box 1
                  _buildInfoBox(
                    context: context,
                    title: "What we collect",
                    items: [
                      _InfoItem('assets/icons/Stethoscope.svg', Icons.medical_services, "Health details you share"),
                      _InfoItem('assets/icons/Watch.svg', Icons.watch, "Data from connected devices"),
                      _InfoItem('assets/icons/settings.svg', Icons.settings, "Your app preferences"),
                    ],
                  ),
                  
                  const SizedBox(height: OnboardingStyle.sectionSpacingSmall * 2),
                  
                  // Box 2
                  _buildInfoBox(
                    context: context,
                    title: "What we do NOT do",
                    items: [
                      _InfoItem('assets/icons/tick.svg', Icons.check, "Never sell your data", iconSize: 12.0),
                      _InfoItem('assets/icons/tick.svg', Icons.check, "Never post without asking", iconSize: 12.0),
                      _InfoItem('assets/icons/tick.svg', Icons.check, "Never contact anyone without consent", iconSize: 12.0),
                    ],
                  ),
                  
                  const SizedBox(height: OnboardingStyle.sectionSpacingSmall * 2),
                  
                  // Box 3 (Choices)
                  _buildChoicesBox(context),
                  
                  const SizedBox(height: OnboardingStyle.sectionSpacingSmall * 2),
                  
                  const NoteRow(
                    text: "We collect nothing without your permission.",
                  ),
                  
                  const SizedBox(height: OnboardingStyle.sectionSpacingLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30.6, sigmaY: 30.6),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(186, 186, 186, 0.13),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color.fromRGBO(186, 186, 186, 0.27), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8.0),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(43, 203, 231, 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      item.iconPath,
                      width: item.iconSize,
                      height: item.iconSize,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      item.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    )));
  }

  Widget _buildChoicesBox(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bgColor = showErrors ? colors.error.withOpacity(0.12) : const Color.fromRGBO(186, 186, 186, 0.13);
    final borderColor = showErrors ? colors.error : const Color.fromRGBO(186, 186, 186, 0.27);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30.6, sigmaY: 30.6),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.only(left: 12.0, right: 3.0, top: 20.0, bottom: 20.0),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your choices",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2.0),
          
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
    )));
  }
}

class _InfoItem {
  final String iconPath;
  final IconData fallbackIcon;
  final String text;
  final double iconSize;

  _InfoItem(this.iconPath, this.fallbackIcon, this.text, {this.iconSize = 16.0});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uncheckedTrack = !isDark ? const Color.fromRGBO(203, 206, 212, 1) : const Color.fromRGBO(55, 58, 66, 1);

    return Column(
      children: [
        if (addTopDivider)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 9.0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: OnboardingColors.fieldBorder.withOpacity(0.1),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color.fromRGBO(107, 107, 107, 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: checked,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  onChanged(val);
                },
                activeColor: Theme.of(context).colorScheme.background,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Theme.of(context).colorScheme.background,
                inactiveTrackColor: uncheckedTrack,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
