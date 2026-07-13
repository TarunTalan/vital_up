import 'package:flutter/material.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';

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
    // Generate layout preview rows
    final List<List<StatMetric>> previewRows = [];
    for (var i = 0; i < _selected.length; i += 3) {
      previewRows.add(_selected.sublist(
        i,
        (i + 3) > _selected.length ? _selected.length : i + 3,
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CUSTOMIZE LAYOUT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SAVE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Preview Panel ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '00:15:32',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  'DURATION',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF999999),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selected.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Select metrics below to preview',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...previewRows.map((rowMetrics) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: rowMetrics.map((metric) {
                          return Expanded(
                            child: Column(
                              children: [
                                Text(
                                  switch (metric) {
                                    StatMetric.distance => '1.82',
                                    StatMetric.calories => '142',
                                    StatMetric.avgPace => '8\'31"',
                                    StatMetric.currentSpeed => '12.5',
                                    StatMetric.steps => '2,400',
                                    StatMetric.elevationGain => '34',
                                    StatMetric.activityType => 'Run',
                                  },
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  metric.label.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF999999),
                                    fontWeight: FontWeight.w800,
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

          // Instruction label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Drag handle (☰) to reorder active metrics. Tap toggles to add or remove.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ),

          // ── Reorderable List of Active & Inactive Metrics ────────────────
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _selected.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final StatMetric item = _selected.removeAt(oldIndex);
                  _selected.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final metric = _selected[index];
                return Container(
                  key: ValueKey(metric),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: Colors.black),
                    title: Text(
                      metric.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: true,
                          activeColor: Colors.black,
                          onChanged: (_) => _toggleMetric(metric, false),
                        ),
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ── Inactive Metrics Section ─────────────────────────────────────
          if (_unselected.isNotEmpty) ...[
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: const Text(
                'AVAILABLE METRICS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: Color(0xFF9A9A9A),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _unselected.length,
                itemBuilder: (context, index) {
                  final metric = _unselected[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey),
                      title: Text(
                        metric.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                      ),
                      trailing: Switch(
                        value: false,
                        onChanged: (_) => _toggleMetric(metric, true),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
