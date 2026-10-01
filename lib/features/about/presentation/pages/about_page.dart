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
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/help_support/domain/entities/support_ticket.dart';
import 'package:vital_up/features/help_support/presentation/widgets/contact_support_sheet.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  int _selectedRating = 5;

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(title: 'About VitalUp'),
      padBody: false,
      scrollable: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.sectionGap,
          context.gutter,
          AppDimens.sectionGap + context.safePadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. App Hero Banner
            _buildHeroBanner(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 2. Direct Link to Rate the App
            _buildRateAppCard(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 3. About the App & Vision
            _buildAboutAppSection(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 4. Key Highlights & Features Grid
            _buildFeatureHighlights(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 5. Technology Stack & Open Source
            _buildTechStackCard(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 7. Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    final v = context.vColors;

    return Center(
      child: Column(
        children: [
          // Glowing App Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_rounded,
                size: 44,
                color: AppColors.buttonText,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          Text(
            'VitalUp',
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            'Your Health, Fitness & Longevity Companion',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snap) {
              final ver = snap.hasData
                  ? 'Version ${snap.data!.version} (${snap.data!.buildNumber})'
                  : 'Version 1.0.0 (1)';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space10,
                  vertical: AppDimens.space4,
                ),
                decoration: BoxDecoration(
                  color: v.glassFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusToast),
                  border: Border.all(
                    color: v.glassBorder ?? AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  ver,
                  style: context.text.labelSmall?.copyWith(
                    color: v.grayText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRateAppCard(BuildContext context) {
    final v = context.vColors;

    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.warning, size: 24),
              const SizedBox(width: AppDimens.space6),
              Text(
                'Enjoying VitalUp?',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            'Your rating and feedback help us build a better wellness experience.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: v.grayText),
          ),
          const SizedBox(height: AppDimens.space12),

          // 5-Star Interactive Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              final isFilled = starNum <= _selectedRating;
              return IconButton(
                iconSize: 32,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFilled ? AppColors.warning : v.grayText,
                ),
                onPressed: () {
                  setState(() => _selectedRating = starNum);
                  HapticFeedback.selectionClick();
                  if (starNum <= 3) {
                    showContactSupportSheet(
                      context,
                      initialCategory: SupportCategory.general,
                      initialSubject: 'Feedback ($starNum Stars)',
                    );
                  }
                },
              );
            }),
          ),
          const SizedBox(height: AppDimens.space12),

          AppPrimaryButton(
            label: 'Rate on Store ⭐',
            onTap: _rateApp,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutAppSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCaption('ABOUT THE APP'),
        const SizedBox(height: AppDimens.space8),
        AppCard(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VitalUp was designed to eliminate fragmented fitness tracking by bringing every pillar of daily health into one intuitive, offline-first dashboard.',
                style: context.text.bodyMedium?.copyWith(
                  height: 1.5,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimens.space12),
              Text(
                'From real-time GPS routes and audio split announcements to sub-second food barcode OCR and interactive 24-hour sleep dials, VitalUp empowers you to build lasting habits with effortless precision.',
                style: context.text.bodyMedium?.copyWith(
                  height: 1.5,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureHighlights(BuildContext context) {
    final v = context.vColors;

    final features = [
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
        color: AppColors.teal,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCaption('CORE HIGHLIGHTS'),
        const SizedBox(height: AppDimens.space8),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.space8),
            child: AppCard(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.space12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimens.space10),
                    decoration: BoxDecoration(
                      color: f.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Icon(f.icon, color: f.color, size: AppDimens.iconMd),
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space2),
                        Text(
                          f.desc,
                          style: context.text.bodySmall?.copyWith(
                            color: v.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechStackCard(BuildContext context) {
    final v = context.vColors;

    final tags = [
      'Flutter & Dart',
      'Supabase Cloud',
      'Isar Community DB',
      'Mapbox Vector Maps',
      'Google ML Kit OCR',
      'Health Connect',
      'Clean Architecture',
      'BLoC Pattern',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCaption('TECHNOLOGY & INFRASTRUCTURE'),
        const SizedBox(height: AppDimens.space8),
        AppCard(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Built with modern open-source technologies for high performance, reliability, and security.',
                style: context.text.bodySmall?.copyWith(color: v.grayText),
              ),
              const SizedBox(height: AppDimens.space12),
              Wrap(
                spacing: AppDimens.space6,
                runSpacing: AppDimens.space6,
                children: tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space10,
                      vertical: AppDimens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: v.primaryFill,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                        color: v.primaryBorder ?? AppColors.primaryBorder,
                      ),
                    ),
                    child: Text(
                      t,
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final v = context.vColors;
    return Center(
      child: Column(
        children: [
          Text(
            'Made with ❤️ for a healthier world.',
            style: context.text.bodySmall?.copyWith(
              color: v.grayText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            '© 2026 VitalUp Team · All rights reserved.',
            style: context.text.labelSmall?.copyWith(color: v.grayText),
          ),
        ],
      ),
    );
  }
}
