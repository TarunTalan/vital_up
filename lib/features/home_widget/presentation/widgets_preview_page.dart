import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';
import 'package:vital_up/features/home_widget/presentation/widget_previews.dart';

/// What the previews draw: the same saved values the home screen widgets
/// read, so both show the same thing.
class WidgetPreviewData {
  final WidgetInputs inputs;
  final DateTime? updatedAt;
  final CustomWidgetConfig custom;

  /// No saved data yet (or not Android): previews show example values.
  final bool example;

  const WidgetPreviewData(
    this.inputs,
    this.updatedAt,
    this.custom, {
    this.example = false,
  });

  static final _example = WidgetInputs(
    signedIn: true,
    day: WidgetInputs.dayOf(DateTime.now()),
    activityMetric: 'steps',
    activityCurrent: 6240,
    activityTarget: 8000,
    caloriesEaten: 1420,
    caloriesGoal: 2100,
    waterMl: 1250,
    sleepMinutes: 430,
    moodLevel: 2,
    moodAt: DateTime.now().subtract(const Duration(hours: 2)),
    weightKg: 72.4,
    weightAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  static Future<WidgetPreviewData> load() async {
    final custom = await _safe(
      CustomWidgetConfig.load(),
      const CustomWidgetConfig(),
    );
    final inputs = await _safe(WidgetInputs.load(), null);
    if (inputs == null) {
      return WidgetPreviewData(_example, DateTime.now(), custom, example: true);
    }
    final ms = await _safe(
      HomeWidget.getWidgetData<String>('updated_at_ms'),
      null,
    );
    final at = ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.tryParse(ms) ?? 0);
    return WidgetPreviewData(inputs, at, custom);
  }

  /// Widget storage isn't set up on iOS; fall back instead of failing.
  static Future<T> _safe<T>(Future<T> f, T fallback) async {
    try {
      return await f;
    } catch (_) {
      return fallback;
    }
  }
}

/// Adds a widget to the home screen through the launcher's pin dialog, or
/// explains how to add it by hand when the launcher can't.
Future<void> pinWidget(BuildContext context, String provider) async {
  HapticFeedback.lightImpact();
  try {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (supported) {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: provider);
      return;
    }
  } catch (_) {}
  if (!context.mounted) return;
  await showSmoothDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add from your home screen'),
      content: const Text(
        'Touch and hold an empty spot on your home screen, tap Widgets, '
        'find VitalUp, then drag the widget into place.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class WidgetsPreviewPage extends StatefulWidget {
  const WidgetsPreviewPage({super.key});

  @override
  State<WidgetsPreviewPage> createState() => _WidgetsPreviewPageState();
}

class _WidgetsPreviewPageState extends State<WidgetsPreviewPage> {
  late Future<WidgetPreviewData> _data = WidgetPreviewData.load();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Bring the saved values (and the home screen) up to date.
    _refresh();
  }

  void _reload() {
    setState(() {
      _data = WidgetPreviewData.load();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      if (HomeWidgetService.supported) {
        await sl<HomeWidgetService>().refresh();
      }
    } finally {
      if (mounted) {
        _refreshing = false;
        _reload();
      }
    }
  }

  Future<void> _customize() async {
    await context.pushNamed('custom-widget-builder');
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final android = HomeWidgetService.supported;
    return AppScaffold(
      header: const AppPageHeader(
        title: 'Widgets',
        subtitle: 'Your day on the home screen',
      ),
      onRefresh: _refresh,
      body: FutureBuilder<WidgetPreviewData>(
        future: _data,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.only(top: AppDimens.space48),
              child: Center(child: VitalUpLoader()),
            );
          }
          final i = data.inputs;
          final at = data.updatedAt;
          return WidgetRefreshing(
            refreshing: _refreshing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInfoNote(
                  message: !android
                      ? 'Home screen widgets are available on Android. These previews use example values.'
                      : data.example
                      ? 'Previews show example values until your data loads. Pull down to refresh.'
                      : 'Previews show your data as it appears on the home screen. '
                            'Touch and hold a widget there to resize it.',
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _WidgetCard(
                  title: 'Today',
                  description:
                      'Activity, calories, water and sleep, like Home.',
                  providers: WidgetSizeProviders.today,
                  initial: WidgetSize.wide,
                  canPin: android,
                  preview: (size) => MetricsWidgetPreview(
                    title: 'Today',
                    metrics: WidgetMetric.today,
                    inputs: i,
                    updatedAt: at,
                    size: size,
                  ),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _WidgetCard(
                  title: data.custom.title,
                  description: 'Up to four metrics you choose, in your order.',
                  providers: WidgetSizeProviders.custom,
                  initial: WidgetSize.wide,
                  canPin: android,
                  onCustomize: _customize,
                  preview: (size) => MetricsWidgetPreview(
                    title: data.custom.title,
                    metrics: data.custom.metrics,
                    inputs: i,
                    updatedAt: at,
                    size: size,
                  ),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _WidgetCard(
                  title: 'Water',
                  description: 'Log a drink without opening the app.',
                  providers: WidgetSizeProviders.water,
                  initial: WidgetSize.small,
                  canPin: android,
                  preview: (size) =>
                      WaterWidgetPreview(inputs: i, updatedAt: at, size: size),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _WidgetCard(
                  title: 'Mood check-in',
                  description: 'Tap a face to check in for today.',
                  providers: WidgetSizeProviders.mood,
                  initial: WidgetSize.wide,
                  canPin: android,
                  preview: (size) =>
                      MoodWidgetPreview(inputs: i, updatedAt: at, size: size),
                ),
                const SizedBox(height: AppDimens.sectionGap),
                _WidgetCard(
                  title: 'Shortcuts',
                  description:
                      'Scan a meal, log water, start a workout, ask Vita.',
                  providers: WidgetSizeProviders.shortcuts,
                  initial: WidgetSize.bar,
                  canPin: android,
                  preview: (size) => ShortcutsWidgetPreview(size: size),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WidgetCard extends StatefulWidget {
  final String title;
  final String description;

  /// Sizes offered (in order) and the provider that pins each one.
  final Map<WidgetSize, String> providers;
  final WidgetSize initial;
  final bool canPin;
  final Widget Function(WidgetSize size) preview;
  final VoidCallback? onCustomize;

  const _WidgetCard({
    required this.title,
    required this.description,
    required this.providers,
    required this.initial,
    required this.preview,
    required this.canPin,
    this.onCustomize,
  });

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  late WidgetSize _size = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: context.text.titleSmall),
          const SizedBox(height: AppDimens.space2),
          Text(
            widget.description,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          AppSegmentedControl<WidgetSize>(
            values: widget.providers.keys.toList(),
            selected: _size,
            label: (s) => s.label,
            onChanged: (s) => setState(() => _size = s),
          ),
          const SizedBox(height: AppDimens.space16),
          Center(child: widget.preview(_size)),
          const SizedBox(height: AppDimens.space16),
          if (widget.onCustomize != null) ...[
            AppSecondaryButton(
              label: 'Customize',
              leadingIcon: Icon(
                Icons.tune_rounded,
                size: AppDimens.iconMd,
                color: context.vColors.secondaryButtonText,
              ),
              onTap: widget.onCustomize!,
            ),
            if (widget.canPin) const SizedBox(height: AppDimens.space8),
          ],
          if (widget.canPin)
            AppPrimaryButton(
              label: 'Add ${_size.label} to home screen',
              leadingIcon: const Icon(
                Icons.add_rounded,
                size: AppDimens.iconMd,
              ),
              onTap: () => pinWidget(context, widget.providers[_size]!),
            ),
        ],
      ),
    );
  }
}
