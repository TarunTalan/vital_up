import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/app_segmented_control.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/home_widget/data/widget_data.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';
import 'package:vital_up/features/home_widget/presentation/widget_previews.dart';
import 'package:vital_up/features/home_widget/presentation/widgets_preview_page.dart';

/// Builds the "My metrics" widget: a title and up to four metrics, in the
/// order they are picked. The preview is the widget as it will appear.
class CustomWidgetBuilderPage extends StatefulWidget {
  const CustomWidgetBuilderPage({super.key});

  @override
  State<CustomWidgetBuilderPage> createState() =>
      _CustomWidgetBuilderPageState();
}

class _CustomWidgetBuilderPageState extends State<CustomWidgetBuilderPage> {
  final _title = TextEditingController();
  WidgetPreviewData? _data;
  CustomWidgetConfig? _saved;
  List<WidgetMetric> _metrics = [];
  WidgetSize _size = WidgetSize.wide;
  bool _saving = false;

  static const _sizes = [
    WidgetSize.small,
    WidgetSize.wide,
    WidgetSize.large,
    WidgetSize.xLarge,
  ];

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    WidgetPreviewData.load().then((data) {
      if (!mounted) return;
      setState(() {
        _data = data;
        _saved = data.custom;
        _metrics = [...data.custom.metrics];
        _title.text = data.custom.title;
      });
    }).catchError((Object e) {
      debugPrint('Widget data unreadable: $e');
      if (mounted) showErrorSnackBar(context, "Couldn't load the widget. Try again.");
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  CustomWidgetConfig get _config => CustomWidgetConfig(
    title: CustomWidgetConfig.cleanTitle(_title.text),
    metrics: _metrics,
  );

  bool get _dirty =>
      _saved != null &&
      (_config.title != _saved!.title ||
          !_sameOrder(_metrics, _saved!.metrics));

  static bool _sameOrder(List<WidgetMetric> a, List<WidgetMetric> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  void _toggle(WidgetMetric metric) {
    setState(() {
      if (_metrics.contains(metric)) {
        if (_metrics.length > 1) _metrics.remove(metric);
      } else if (_metrics.length < CustomWidgetConfig.maxMetrics) {
        _metrics.add(metric);
      }
    });
  }

  Future<bool> _save() async {
    if (_metrics.isEmpty || _saving) return false;
    setState(() => _saving = true);
    try {
      final config = _config;
      await config.save();
      if (!mounted) return true;
      setState(() => _saved = config);
      showSuccessSnackBar(context, 'Widget saved');
      return true;
    } catch (e) {
      debugPrint('Custom widget not saved: $e');
      if (mounted) {
        showErrorSnackBar(context, "Couldn't save the widget. Try again.");
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndPin() async {
    if (_dirty && !await _save()) return;
    // Pin at the size being previewed.
    if (mounted) {
      await pinWidget(context, WidgetSizeProviders.custom[_size]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    const header = AppPageHeader(
      title: 'My metrics widget',
      subtitle: 'Pick what it shows',
    );
    final data = _data;
    if (data == null) {
      return const AppScaffold(
        header: header,
        body: Padding(
          padding: EdgeInsets.only(top: AppDimens.space48),
          child: Center(child: VitalUpLoader()),
        ),
      );
    }
    final full = _metrics.length >= CustomWidgetConfig.maxMetrics;
    final android = HomeWidgetService.supported;

    return AppScaffold(
      header: header,
      bottomBar: Row(
        children: [
          if (android) ...[
            Expanded(
              child: AppSecondaryButton(
                label: 'Add ${_size.label}',
                onTap: _saveAndPin,
              ),
            ),
            const SizedBox(width: AppDimens.buttonGap),
          ],
          Expanded(
            child: AppPrimaryButton(
              label: _dirty ? 'Save' : 'Saved',
              enabled: _dirty,
              isLoading: _saving,
              onTap: _save,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: AppSegmentedControl<WidgetSize>(
                    compact: true,
                    values: _sizes,
                    selected: _size,
                    label: (s) => s.label,
                    onChanged: (s) => setState(() => _size = s),
                  ),
                ),
                const SizedBox(height: AppDimens.space16),
                Center(
                  child: MetricsWidgetPreview(
                    title: _config.title,
                    metrics: _metrics,
                    inputs: data.inputs,
                    updatedAt: data.updatedAt,
                    size: _size,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          AppInfoNote(
            message: _size == WidgetSize.small
                ? 'At 2 × 2 the widget shows the first two metrics.'
                : _size == WidgetSize.wide
                ? 'At 4 × 2 it shows up to four metrics side by side.'
                : _size == WidgetSize.large
                ? 'At 4 × 3 it shows four metrics in a grid.'
                : 'At 4 × 4 and larger it adds Scan, Water and Vita buttons.',
          ),
          const SizedBox(height: AppDimens.sectionGap),

          const AppSectionHeader('Title'),
          AppTextField(
            controller: _title,
            hint: CustomWidgetConfig.defaultTitle,
            maxLength: CustomWidgetConfig.titleMax,
            inputFormatters: InputFormatters.text(CustomWidgetConfig.titleMax),
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimens.sectionGap),

          AppListGroup(
            title:
                'Metrics (${_metrics.length} of ${CustomWidgetConfig.maxMetrics})',
            children: [
              for (final metric in WidgetMetric.values)
                _MetricOption(
                  metric: metric,
                  position: _metrics.indexOf(metric),
                  enabled: _metrics.contains(metric)
                      ? _metrics.length > 1
                      : !full,
                  onTap: () => _toggle(metric),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          const AppInfoNote(
            message:
                'Metrics appear in the order you pick them. '
                'Tap a picked metric to remove it, then pick it again to move it to the end.',
          ),
        ],
      ),
    );
  }
}

class _MetricOption extends StatelessWidget {
  final WidgetMetric metric;

  /// Order in the widget, or -1 when not picked.
  final int position;
  final bool enabled;
  final VoidCallback onTap;

  const _MetricOption({
    required this.metric,
    required this.position,
    required this.enabled,
    required this.onTap,
  });

  String get _subtitle => switch (metric) {
    WidgetMetric.activity => 'Steps or your main activity goal',
    WidgetMetric.calories => 'Eaten today against your goal',
    WidgetMetric.water => 'Today against your goal',
    WidgetMetric.sleep => 'Last night against your goal',
    WidgetMetric.mood => "Today's check-in",
    WidgetMetric.weight => 'Your latest weigh-in',
  };

  @override
  Widget build(BuildContext context) {
    final picked = position >= 0;
    return Opacity(
      opacity: enabled || picked ? 1 : AppDimens.disabledOpacity,
      child: AppListTile(
        icon: metric.icon,
        iconColor: metric.color,
        title: metric.title,
        subtitle: _subtitle,
        onTap: enabled ? onTap : null,
        trailing: Container(
          width: AppDimens.numberBadge,
          height: AppDimens.numberBadge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: picked ? context.colors.primary : Colors.transparent,
            border: picked
                ? null
                : Border.all(color: context.vColors.secondaryButtonBorder!),
          ),
          child: picked
              ? Text(
                  '${position + 1}',
                  style: context.text.labelSmall?.copyWith(
                    color: context.vColors.buttonText,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
