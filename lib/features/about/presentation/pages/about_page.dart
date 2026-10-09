import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/config/legal_links.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/features/help_support/domain/entities/support_ticket.dart';

/// Feedback text as sent: no invisible characters, at most
/// [InputLimits.note] characters.
String cleanFeedback(String raw) =>
    sanitizeText(raw, maxLength: InputLimits.note, multiline: true);

/// Inline error for the feedback field, or null when it can be sent.
String? validateFeedback(String raw) {
  final text = cleanFeedback(raw);
  if (text.isEmpty) return 'Write your feedback first.';
  if (text.characters.length < 3) return 'Add a few more words.';
  return null;
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  final TextEditingController _feedbackController = TextEditingController();
  int _selectedRating = 5;
  String? _feedbackError;
  bool _sendingFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _rateApp() async {
    HapticFeedback.mediumImpact();
    // The Play id is this build's package name; the App Store id is a
    // placeholder until iOS ships.
    final Uri url;
    final Uri? webFallback;
    if (Platform.isIOS) {
      url = Uri.parse('https://apps.apple.com/app/id123456789?action=write-review');
      webFallback = null;
    } else {
      String appId;
      try {
        appId = (await _packageInfo).packageName;
      } catch (e) {
        debugPrint('Package info unavailable: $e');
        appId = _fallbackPackage;
      }
      url = Uri.parse('market://details?id=$appId');
      webFallback =
          Uri.parse('https://play.google.com/store/apps/details?id=$appId');
    }

    var opened = false;
    for (final target in [url, ?webFallback]) {
      try {
        opened = await launchUrl(target, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Store link not opened ($target): $e');
      }
      if (opened) break;
    }
    if (!opened && mounted) {
      showErrorSnackBar(context, "Couldn't open the store. Try again later.");
    }
  }

  static const _fallbackPackage = 'com.tarun_siddhi.vital_up';

  void _onRate(int stars) {
    setState(() => _selectedRating = stars);
    HapticFeedback.selectionClick();
  }

  Future<void> _submitFeedback() async {
    if (_sendingFeedback) return;
    final error = validateFeedback(_feedbackController.text);
    if (error != null) {
      setState(() => _feedbackError = error);
      return;
    }
    final feedbackText = cleanFeedback(_feedbackController.text);

    FocusScope.of(context).unfocus();
    _sendingFeedback = true;

    PackageInfo? info;
    try {
      info = await _packageInfo;
    } catch (e) {
      debugPrint('Package info unavailable: $e');
    }

    final ver = info != null
        ? '${info.version} (${info.buildNumber})'
        : 'unknown';
    final subject = 'VitalUp Feedback ($_selectedRating Stars)';
    final body =
        '''
Rating: $_selectedRating / 5 Stars

Feedback:
$feedbackText

-------------------------
App Version: $ver
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
-------------------------
''';

    var launched = false;
    try {
      launched = await launchUrl(
        supportMailUri(subject: subject, body: body),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Feedback mail not opened: $e');
    }
    _sendingFeedback = false;
    if (!mounted) return;
    if (launched) {
      showSuccessSnackBar(context, 'Your email app is open. Send it from there.');
      _feedbackController.clear();
      return;
    }
    try {
      await Clipboard.setData(
        ClipboardData(text: 'To: $kSupportEmail\nSubject: $subject\n\n$body'),
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Feedback copied. Paste it into an email to us.');
      }
    } catch (e) {
      debugPrint('Clipboard unavailable: $e');
      if (mounted) showErrorSnackBar(context, 'No email app found. Email $kSupportEmail');
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
            feedbackError: _feedbackError,
            onFeedbackChanged: (_) {
              if (_feedbackError != null) setState(() => _feedbackError = null);
            },
            onRate: _onRate,
            onRateOnStore: _rateApp,
            onSubmitFeedback: _submitFeedback,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const _Section(title: 'About the app', child: _AboutAppCard()),
          const SizedBox(height: AppDimens.sectionGap),
          const _Section(title: 'Core highlights', child: _FeatureHighlights()),
          const SizedBox(height: AppDimens.sectionGap),
          const _LegalLinks(),
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
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.primary,
          ),
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
  final String? feedbackError;
  final ValueChanged<String> onFeedbackChanged;
  final ValueChanged<int> onRate;
  final VoidCallback onRateOnStore;
  final VoidCallback onSubmitFeedback;

  const _RateAppCard({
    required this.rating,
    required this.feedbackController,
    required this.feedbackError,
    required this.onFeedbackChanged,
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
              multiline: true,
              minLines: 3,
              maxLines: 4,
              maxLength: InputLimits.note,
              inputFormatters: InputFormatters.text(
                InputLimits.note,
                multiline: true,
              ),
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              error: feedbackError,
              onChanged: onFeedbackChanged,
              showCounter: true,
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
      desc:
          'Mapbox vector maps, customizable live HUD, and Voice Coach intervals.',
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
      desc:
          'Instant offline ML Kit nutrition OCR and personalized diet planning.',
    ),
    (
      icon: Icons.phone_android_rounded,
      color: ActivityColors.accentPurple,
      title: 'Screen Time Wellness',
      desc:
          '7-day usage trends, daily averages, and nighttime digital detox nudges.',
    ),
    (
      icon: Icons.sync_rounded,
      color: AppColors.success,
      title: 'Offline First & Health Sync',
      desc:
          'Encrypted Isar databases with Health Connect and Supabase cloud sync.',
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

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  Future<void> _open(BuildContext context, String url) async {
    if (!await LegalLinks.open(url) && context.mounted) {
      showErrorSnackBar(context, "Couldn't open the page. Try again later.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppListGroup(
      title: 'Legal',
      children: [
        AppListTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _open(context, LegalLinks.privacyPolicy),
        ),
        AppListTile(
          icon: Icons.description_outlined,
          title: 'Terms of use',
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _open(context, LegalLinks.terms),
        ),
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
          'Made with care for a healthier world.',
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
