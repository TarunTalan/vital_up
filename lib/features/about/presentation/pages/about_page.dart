import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  final TextEditingController _feedbackController = TextEditingController();
  int _selectedRating = 5;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _rateApp() async {
    HapticFeedback.mediumImpact();
    // Use store intent or fallback web url
    final String appId = Platform.isIOS ? 'id123456789' : 'com.vitalup.app';
    final Uri url = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/app/$appId?action=write-review'
          : 'market://details?id=$appId',
    );
    final Uri webFallback = Uri.parse(
      'https://play.google.com/store/apps/details?id=$appId',
    );

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Thank you for rating VitalUp $_selectedRating ⭐!',
        );
      }
    }
  }

  void _onRate(int stars) {
    setState(() => _selectedRating = stars);
    HapticFeedback.selectionClick();
  }

  Future<void> _submitFeedback() async {
    final feedbackText = _feedbackController.text.trim();
    if (feedbackText.isEmpty) {
      showErrorSnackBar(context, 'Please enter your feedback before submitting.');
      return;
    }

    FocusScope.of(context).unfocus();

    PackageInfo? info;
    try {
      info = await _packageInfo;
    } catch (_) {}

    final ver = info != null ? '${info.version} (${info.buildNumber})' : '1.0.0 (1)';
    final subject = 'VitalUp Feedback ($_selectedRating Stars)';
    final body = '''
Rating: $_selectedRating / 5 Stars

Feedback:
$feedbackText

-------------------------
App Version: $ver
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
-------------------------
''';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@vitalup.app',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: 'To: support@vitalup.app\nSubject: $subject\n\n$body'));
        if (mounted) {
          showSuccessSnackBar(
            context,
            'Feedback copied to clipboard. You can paste into your email to support@vitalup.app',
          );
        }
      } else if (mounted) {
        showSuccessSnackBar(context, 'Thank you! Email opened in your mail app.');
        _feedbackController.clear();
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: 'To: support@vitalup.app\nSubject: $subject\n\n$body'));
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Feedback copied to clipboard. You can paste into your email to support@vitalup.app',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'About VitalUp'),
      bodyPadding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.sectionGap,
        context.gutter,
        AppDimens.sectionGap + context.safePadding.bottom,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBanner(packageInfo: _packageInfo),
          const SizedBox(height: AppDimens.sectionGap),
          _RateAppCard(
            rating: _selectedRating,
            feedbackController: _feedbackController,
            onRate: _onRate,
            onRateOnStore: _rateApp,
            onSubmitFeedback: _submitFeedback,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const _Section(title: 'About the app', child: _AboutAppCard()),
          const SizedBox(height: AppDimens.sectionGap),
          const _Section(title: 'Core highlights', child: _FeatureHighlights()),
          const SizedBox(height: AppDimens.sectionGap),
          const _Footer(),
        ],
      ),
    );
  }
}

/// Caption eyebrow above a block of content.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCaption(title),
        const SizedBox(height: AppDimens.space8),
        child,
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final Future<PackageInfo> packageInfo;

  const _HeroBanner({required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final logoSize = context.w(AppDimens.avatarLarge);

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
            boxShadow: AppShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
            child: SvgPicture.asset(
              'assets/icons/app_icon.svg',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.space16),
        Text(
          'VitalUp',
          textAlign: TextAlign.center,
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: AppDimens.space4),
        Text(
          'Your Health, Fitness & Longevity Companion',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.colors.primary),
        ),
        const SizedBox(height: AppDimens.space12),
        FutureBuilder<PackageInfo>(
          future: packageInfo,
          builder: (context, snap) {
            final ver = snap.hasData
                ? 'Version ${snap.data!.version} (${snap.data!.buildNumber})'
                : 'Version 1.0.0 (1)';
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space4,
              ),
              decoration: BoxDecoration(
                color: v.glassFill,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                border: Border.all(color: v.glassBorder!),
              ),
              child: Text(
                ver,
                style: context.text.labelSmall?.copyWith(color: v.grayText),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RateAppCard extends StatelessWidget {
  final int rating;
  final TextEditingController feedbackController;
  final ValueChanged<int> onRate;
  final VoidCallback onRateOnStore;
  final VoidCallback onSubmitFeedback;

  const _RateAppCard({
    required this.rating,
    required this.feedbackController,
    required this.onRate,
    required this.onRateOnStore,
    required this.onSubmitFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isLowRating = rating <= 3;

    return AppCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Enjoying VitalUp?',
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            isLowRating
                ? 'We want to make things right. Tell us how we can improve your experience:'
                : 'Your rating and feedback help us build a better wellness experience.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: v.grayText),
          ),
          const SizedBox(height: AppDimens.space12),
          // Scales down instead of overflowing on narrow phones.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final stars = index + 1;
                  final filled = stars <= rating;
                  return IconButton(
                    tooltip: '$stars star${stars == 1 ? '' : 's'}',
                    iconSize: AppDimens.iconXl,
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? v.warning : v.grayText,
                    ),
                    onPressed: () => onRate(stars),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          if (isLowRating) ...[
            AppTextField(
              controller: feedbackController,
              hint: 'Describe your feedback, issues, or suggestions...',
              minLines: 3,
              maxLines: 4,
              maxLength: 500,
              showCounter: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppDimens.space12),
            AppPrimaryButton(
              label: 'Submit Feedback',
              leadingIcon: const Icon(Icons.mail_outline_rounded),
              onTap: onSubmitFeedback,
            ),
          ] else ...[
            AppPrimaryButton(label: 'Rate on Store', onTap: onRateOnStore),
          ],
        ],
      ),
    );
  }
}

class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard();

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurface,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VitalUp was designed to eliminate fragmented fitness tracking by bringing every pillar of daily health into one intuitive, offline-first dashboard.',
            style: style,
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            'From real-time GPS routes and audio split announcements to sub-second food barcode OCR and interactive 24-hour sleep dials, VitalUp empowers you to build lasting habits with effortless precision.',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlights extends StatelessWidget {
  const _FeatureHighlights();

  static const _features = [
    (
      icon: Icons.directions_run_rounded,
      color: AppColors.primary,
      title: 'Precision GPS Tracking',
      desc: 'Mapbox vector maps, customizable live HUD, and Voice Coach intervals.',
    ),
    (
      icon: Icons.water_drop_rounded,
      color: AppColors.water,
      title: 'Smart Hydration Pace',
      desc: '1-tap glassware presets with hourly hydration pace status alerts.',
    ),
    (
      icon: Icons.bedtime_rounded,
      color: AppColors.sleep,
      title: 'Circular Sleep Dial & Score',
      desc: '24-hour dual-knob clock with sleep debt and stage analysis.',
    ),
    (
      icon: Icons.camera_alt_rounded,
      color: AppColors.protein,
      title: 'AI Food Scanner & Vita',
      desc: 'Instant offline ML Kit nutrition OCR and personalized diet planning.',
    ),
    (
      icon: Icons.phone_android_rounded,
      color: ActivityColors.accentPurple,
      title: 'Screen Time Wellness',
      desc: '7-day usage trends, daily averages, and nighttime digital detox nudges.',
    ),
    (
      icon: Icons.sync_rounded,
      color: AppColors.success,
      title: 'Offline First & Health Sync',
      desc: 'Encrypted Isar databases with Health Connect and Supabase cloud sync.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    final tiles = [
      for (final f in _features)
        AppCard(
          padding: AppDimens.cardPaddingCompact,
          child: Row(
            children: [
              AppIconBadge(icon: Icon(f.icon), color: f.color),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title, style: context.text.titleSmall),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      f.desc,
                      style: context.text.bodySmall?.copyWith(color: v.grayText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];

    // Two columns on tablets, a single list on phones.
    if (context.isTablet) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - AppDimens.cardGap) / 2;
          return Wrap(
            spacing: AppDimens.cardGap,
            runSpacing: AppDimens.cardGap,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.space8),
          tiles[i],
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return Column(
      children: [
        Text(
          'Made with ❤️ for a healthier world.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: grey),
        ),
        const SizedBox(height: AppDimens.space4),
        Text(
          '© 2026 VitalUp Team · All rights reserved.',
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(color: grey),
        ),
      ],
    );
  }
}
