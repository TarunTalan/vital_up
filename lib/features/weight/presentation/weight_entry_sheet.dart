import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Asks for today's weight; returns true once saved.
Future<bool> showWeightEntrySheet(BuildContext context) async {
  final service = sl<WeightService>();
  final unit = await service.unit();
  final latest = await service.latest();
  if (!context.mounted) return false;
  final saved = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => _WeightEntrySheet(
      unit: unit,
      initial: latest == null
          ? ''
          : unit.fromKg(latest.weightKg).toStringAsFixed(1),
    ),
  );
  return saved == true;
}

class _WeightEntrySheet extends StatefulWidget {
  final WeightUnit unit;
  final String initial;

  const _WeightEntrySheet({required this.unit, required this.initial});

  @override
  State<_WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<_WeightEntrySheet> {
  static final _pattern = RegExp(r'^\d{0,3}([.,]\d?)?$');

  late final _value = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final (:kg, :error) = parseWeightEntry(_value.text, widget.unit);
    if (kg == null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    String? saveError;
    try {
      saveError = await sl<WeightService>().add(kg);
    } catch (e) {
      debugPrint('Weight not saved: $e');
      saveError = "Couldn't save your weight. Try again.";
    }
    if (!mounted) return;
    if (saveError == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = saveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrackerSheet(
      metric: TrackerMetric.weight,
      title: 'Log weight',
      subtitle: 'Weigh in at the same time of day for a steady trend',
      action: AppPrimaryButton(label: 'Save', isLoading: _saving, onTap: _save),
      child: AppTextField(
        label: 'Weight',
        controller: _value,
        hint: '0.0',
        suffixText: widget.unit.label,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // Up to 3 digits and one decimal place; "," for locales that use it.
          TextInputFormatter.withFunction(
            (old, next) => _pattern.hasMatch(next.text) ? next : old,
          ),
          LengthLimitingTextInputFormatter(weightInputMaxLength),
        ],
        textInputAction: TextInputAction.done,
        enabled: !_saving,
        autofocus: true,
        error: _error,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    );
  }
}
