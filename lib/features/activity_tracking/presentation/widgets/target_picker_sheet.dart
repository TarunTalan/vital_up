import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';

/// Bottom sheet for selecting a workout target (distance or calories).
class TargetPickerSheet extends StatefulWidget {
  final WorkoutPrefs current;
  final DistanceUnit distanceUnit;

  const TargetPickerSheet({
    super.key,
    required this.current,
    required this.distanceUnit,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutPrefs current,
    required DistanceUnit distanceUnit,
    required WorkoutPrefsNotifier notifier,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TargetPickerSheet(
        current: current,
        distanceUnit: distanceUnit,
      ),
    ).then((result) {
      if (result == null) return;
      final (WorkoutTargetType type, double val) = result;
      notifier.setTarget(type, val);
    });
  }

  @override
  State<TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<TargetPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _distCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);

    // Pre-fill existing values
    if (widget.current.targetType == WorkoutTargetType.distance) {
      final displayVal = widget.distanceUnit == DistanceUnit.miles
          ? widget.current.targetValue / 1.60934
          : widget.current.targetValue;
      _distCtrl.text = displayVal.toStringAsFixed(1);
      _tabs.animateTo(0);
    } else if (widget.current.targetType == WorkoutTargetType.calories) {
      _calCtrl.text = widget.current.targetValue.toStringAsFixed(0);
      _tabs.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _distCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  void _confirm(WorkoutTargetType type) {
    double val = 0;
    if (type == WorkoutTargetType.distance) {
      val = double.tryParse(_distCtrl.text) ?? 0;
      if (widget.distanceUnit == DistanceUnit.miles) val *= 1.60934;
    } else {
      val = double.tryParse(_calCtrl.text) ?? 0;
    }
    if (val <= 0) {
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop((type, val));
  }

  @override
  Widget build(BuildContext context) {
    final distUnitLabel = widget.distanceUnit.label.toUpperCase();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'WORKOUT TARGET',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF888888),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'DISTANCE ($distUnitLabel)'),
                    const Tab(text: 'CALORIES (KCAL)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              SizedBox(
                height: 80,
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _NumberField(
                      controller: _distCtrl,
                      hint: 'e.g. 5.0',
                      suffix: distUnitLabel,
                    ),
                    _NumberField(
                      controller: _calCtrl,
                      hint: 'e.g. 500',
                      suffix: 'kcal',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Confirm / Clear buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'CLEAR',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF888888),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final type = _tabs.index == 0
                            ? WorkoutTargetType.distance
                            : WorkoutTargetType.calories;
                        _confirm(type);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'SET TARGET',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Color(0xFFCCCCCC),
        ),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF888888),
        ),
      ),
    );
  }
}
