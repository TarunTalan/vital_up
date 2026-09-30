import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_tracking_stats.dart';

class CustomizeLayoutPage extends StatefulWidget {
  final WorkoutPrefsNotifier prefsNotifier;

  const CustomizeLayoutPage({super.key, required this.prefsNotifier});

  @override
  State<CustomizeLayoutPage> createState() => _CustomizeLayoutPageState();
}

class _CustomizeLayoutPageState extends State<CustomizeLayoutPage> {
  late List<StatMetric> _selected;
  late List<StatMetric> _unselected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.prefsNotifier.value.selectedMetrics);
    _unselected = StatMetric.values
        .where((m) => !_selected.contains(m))
        .toList();
  }

  void _save() {
    widget.prefsNotifier.setSelectedMetrics(_selected);
    Navigator.of(context).pop();
  }

  void _toggleMetric(StatMetric metric, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selected.length >= 6) {
          showErrorSnackBar(context, 'Maximum of 6 metrics can be displayed');
          return;
        }
        _unselected.remove(metric);
        _selected.add(metric);
      } else {
        if (_selected.length <= 1) {
          showErrorSnackBar(context, 'At least 1 metric must be displayed');
          return;
        }
        _selected.remove(metric);
        _unselected.add(metric);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;

    // Generate layout preview rows
    final List<List<StatMetric>> previewRows = [];
    for (var i = 0; i < _selected.length; i += 3) {
      previewRows.add(
        _selected.sublist(
          i,
          (i + 3) > _selected.length ? _selected.length : (i + 3),
        ),
      );
    }

    return AppScaffold(
      header: AppPageHeader(
        title: 'Customize Layout',
        action: AppHeaderAction(
          icon: const Icon(Icons.check_rounded),
          tooltip: 'Save',
          onTap: _save,
        ),
      ),
      scrollable: false,
      padBody: false,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Preview panel
            AppCard(
              margin: EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.space16,
                context.gutter,
                AppDimens.space8,
              ),
              padding: AppDimens.cardPaddingCompact,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppCaption('Layout preview'),
                  const SizedBox(height: AppDimens.space12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '00:05:42',
                      style: AppTextStyles.metric.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space2),
                  Text(
                    'Duration',
                    style: context.text.labelSmall?.copyWith(
                      color: v.grayText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ...previewRows.map((rowMetrics) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppDimens.space12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rowMetrics.map((metric) {
                          final (value, label) = _getMetricPreviewData(metric);
                          return Expanded(
                            child: StatColumn(value: value, label: label),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Active metrics header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.gutter,
                vertical: AppDimens.space8,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: AppCaption('Active stats (drag to reorder)'),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Text(
                    '${_selected.length}/6',
                    style: context.text.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Active metrics list
            Expanded(
              child: Theme(
                data: context.theme.copyWith(
                  canvasColor: Colors
                      .transparent, // Prevents white background during drag
                ),
                child: ReorderableListView.builder(
                  padding: context.pagePadding,
                  itemCount: _selected.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _selected.removeAt(oldIndex);
                      _selected.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final metric = _selected[index];
                    return Padding(
                      key: ValueKey(metric),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.space4,
                      ),
                      child: AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Icons.drag_handle_rounded,
                            color: v.grayText,
                          ),
                          title: Text(
                            metric.label,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: colors.error,
                            ),
                            onPressed: () => _toggleMetric(metric, false),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Available metrics
            if (_unselected.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  AppDimens.space8,
                  context.gutter,
                  AppDimens.sectionGap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCaption('Available stats'),
                    const SizedBox(height: AppDimens.space8),
                    Wrap(
                      spacing: AppDimens.space8,
                      runSpacing: AppDimens.space8,
                      children: [
                        for (final metric in _unselected)
                          _AvailableMetricChip(
                            label: metric.label,
                            onTap: () => _toggleMetric(metric, true),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, String) _getMetricPreviewData(StatMetric metric) {
    return switch (metric) {
      StatMetric.distance => ('1.24', 'DISTANCE (KM)'),
      StatMetric.calories => ('108', 'CALORIES'),
      StatMetric.avgPace => ('5\'34"', 'AVG. PACE'),
      StatMetric.currentSpeed => ('12.4', 'SPEED (KM/H)'),
      StatMetric.steps => ('1,850', 'STEPS'),
      StatMetric.elevationGain => ('24', 'ELEV. GAIN (M)'),
      StatMetric.activityType => ('Run', 'ACTIVITY'),
    };
  }
}

class _AvailableMetricChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AvailableMetricChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return Material(
      color: v.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        side: BorderSide(color: v.glassBorder!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: context.colors.primary,
                size: AppDimens.iconSm,
              ),
              const SizedBox(width: AppDimens.space6),
              Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
