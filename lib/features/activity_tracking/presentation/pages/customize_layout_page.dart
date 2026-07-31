import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';

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
    _unselected = StatMetric.values.where((m) => !_selected.contains(m)).toList();
  }

  void _save() {
    widget.prefsNotifier.setSelectedMetrics(_selected);
    Navigator.of(context).pop();
  }

  void _toggleMetric(StatMetric metric, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selected.length >= 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum of 6 metrics can be displayed')),
          );
          return;
        }
        _unselected.remove(metric);
        _selected.add(metric);
      } else {
        if (_selected.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('At least 1 metric must be displayed')),
          );
          return;
        }
        _selected.remove(metric);
        _unselected.add(metric);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    // Generate layout preview rows
    final List<List<StatMetric>> previewRows = [];
    for (var i = 0; i < _selected.length; i += 3) {
      previewRows.add(_selected.sublist(
        i,
        (i + 3) > _selected.length ? _selected.length : (i + 3),
      ));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: BackIcon(
              onClick: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          'CUSTOMIZE LAYOUT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'SAVE',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.primary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Preview Panel ───────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.light 
                        ? Colors.white.withValues(alpha: 0.72) 
                        : colors.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: (theme.brightness == Brightness.light 
                          ? const Color(0xFFD8D8D8) 
                          : colors.outline).withValues(alpha: 0.72),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: theme.brightness == Brightness.light ? 0.04 : 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LAYOUT PREVIEW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Duration preview
                      Text(
                        '00:05:42',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DURATION',
                        style: TextStyle(
                          color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                          fontSize: 8.5,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Rows preview
                      ...previewRows.map((rowMetrics) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rowMetrics.map((metric) {
                              final (value, label) = _getMetricPreviewData(metric);
                              return Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          height: 1.0,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                                        fontSize: 8.0,
                                        letterSpacing: 0.3,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                // ── Active Metrics Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'ACTIVE STATS (DRAG TO REORDER)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selected.length}/6',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Active Metrics List ──────────────────────────────────────────
                Expanded(
                  child: Theme(
                    data: theme.copyWith(
                      canvasColor: Colors.transparent, // Prevents white background during drag
                    ),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        return Card(
                          key: ValueKey(metric),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: theme.brightness == Brightness.light
                              ? Colors.white.withValues(alpha: 0.72)
                              : colors.surface.withValues(alpha: 0.72),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: (theme.brightness == Brightness.light
                                  ? const Color(0xFFD8D8D8)
                                  : colors.outline).withValues(alpha: 0.72),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.drag_handle_rounded,
                              color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                            ),
                            title: Text(
                              metric.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: colors.error,
                              ),
                              onPressed: () => _toggleMetric(metric, false),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Available Metrics Section ────────────────────────────────────
                if (_unselected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AVAILABLE STATS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: customColors?.grayText ?? const Color(0xFF9A9A9A),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 90,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _unselected.length,
                      itemBuilder: (context, index) {
                        final metric = _unselected[index];
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: InkWell(
                            onTap: () => _toggleMetric(metric, true),
                            borderRadius: BorderRadius.circular(10),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.light
                                    ? Colors.white.withValues(alpha: 0.72)
                                    : colors.surface.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (theme.brightness == Brightness.light
                                      ? const Color(0xFFD8D8D8)
                                      : colors.outline).withValues(alpha: 0.72),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      metric.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: colors.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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


