import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/tracker/tracker_metric.dart';
import 'package:vital_up/core/widgets/tracker/tracker_sheet.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/core/widgets/value_ruler.dart';
import 'package:vital_up/features/activity_tracking/data/services/body_weight_source.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

const _metric = TrackerMetric.weight;

/// Where the scale starts with no weight on record at all.
const _fallbackKg = 70.0;

/// Asks for today's weight; returns true once saved.
Future<bool> showWeightEntrySheet(BuildContext context) async {
  final service = sl<WeightService>();
  final unit = await service.unit();
  final latest = await service.latest();
  final goal = await service.targetKg();
  // No weigh-in yet: start from the profile's weight, else a typical one.
  final start =
      latest?.weightKg ?? await sl<BodyWeightSource>()() ?? _fallbackKg;
  if (!context.mounted) return false;
  final saved = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => WeightEntrySheet(
      unit: unit,
      startKg: start,
      last: latest,
      goalKg: goal,
    ),
  );
  return saved == true;
}

/// Weight entry: a large readout over a sliding scale (drag or fling, it
/// snaps to 0.1), the change since the last weigh-in and the way to the
/// goal, and a switch to typing the number instead.
class WeightEntrySheet extends StatefulWidget {
  final WeightUnit unit;

  /// Where the scale starts, in kg.
  final double startKg;

  /// The last weigh-in, for "0.7 kg less than 13 Oct".
  final WeightLogCache? last;
  final double? goalKg;

  /// Starts on the keyboard instead of the scale (tests).
  final bool typing;

  const WeightEntrySheet({
    super.key,
    required this.unit,
    required this.startKg,
    this.last,
    this.goalKg,
    this.typing = false,
  });

  @override
  State<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<WeightEntrySheet> {
  static final _pattern = RegExp(r'^\d{0,3}([.,]\d?)?$');

  WeightUnit get _unit => widget.unit;

  /// The picked weight in [_unit], one decimal.
  late double _value = _roundTenth(
    _unit
        .fromKg(widget.startKg)
        .clamp(_unit.minValue.toDouble(), _unit.maxValue.toDouble()),
  );

  late bool _typing = widget.typing;
  late final _text = TextEditingController(text: _value.toStringAsFixed(1));
  String? _error;
  bool _saving = false;

  static double _roundTenth(double v) => double.parse(v.toStringAsFixed(1));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _setTyping(bool typing) {
    setState(() {
      _typing = typing;
      _error = null;
      if (typing) {
        _text.text = _value.toStringAsFixed(1);
      } else {
        // Back to the scale at what was typed, when it's a valid weight.
        final (:kg, error: _) = parseWeightEntry(_text.text, _unit);
        if (kg != null) _value = _roundTenth(_unit.fromKg(kg));
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final (:kg, :error) = parseWeightEntry(
      _typing ? _text.text : _value.toStringAsFixed(1),
      _unit,
    );
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
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = saveError;
      });
    }
  }

  /// The shown weight in kg ([_value], or what's typed when valid).
  double? get _kg {
    if (!_typing) return _unit.toKg(_value);
    return parseWeightEntry(_text.text, _unit).kg;
  }

  /// "0.7 kg less than 13 Oct", "2.4 kg to your goal".
  List<String> _facts() {
    final kg = _kg;
    if (kg == null) return const [];
    final facts = <String>[];
    final last = widget.last;
    if (last == null) {
      facts.add('Your first weigh-in');
    } else {
      final diff = _unit.fromKg(kg) - _unit.fromKg(last.weightKg);
      final day = DateUtils.isSameDay(last.timestamp, DateTime.now())
          ? 'earlier today'
          : DateFormat('d MMM').format(last.timestamp);
      final amount = '${diff.abs().toStringAsFixed(1)} ${_unit.label}';
      facts.add(
        diff.abs() < 0.05
            ? 'Same as $day'
            : diff < 0
            ? '$amount less than $day'
            : '$amount more than $day',
      );
    }
    final goal = widget.goalKg;
    if (goal != null) {
      final left = (_unit.fromKg(goal) - _unit.fromKg(kg)).abs();
      // Same threshold as the Weight card's "Goal reached".
      facts.add(
        (goal - kg).abs() <= weightGoalReachedKg
            ? 'At your goal'
            : '${left.toStringAsFixed(1)} ${_unit.label} to your goal',
      );
    }
    return facts;
  }

  @override
  Widget build(BuildContext context) {
    final kg = _kg;
    final label = kg == null
        ? 'Save'
        : 'Save ${_unit.fromKg(kg).toStringAsFixed(1)} ${_unit.label}';
    return TrackerSheet(
      metric: _metric,
      title: 'Log weight',
      subtitle: 'Weigh in at the same time of day for a steady trend',
      action: AppPrimaryButton(label: label, isLoading: _saving, onTap: _save),
      child: AnimatedSize(
        duration: AppDurations.medium,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_typing) _typed() else _scale(),
            const SizedBox(height: AppDimens.space12),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : () => _setTyping(!_typing),
                icon: Icon(
                  _typing ? Icons.straighten_rounded : Icons.keyboard_rounded,
                  size: AppDimens.iconSm,
                ),
                label: Text(_typing ? 'Use the scale' : 'Type instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scale() {
    final facts = _facts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _value.toStringAsFixed(1),
                  style: AppTextStyles.metricLarge.copyWith(
                    color: context.colors.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' ${_unit.label}',
                  style: context.text.titleSmall?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
            semanticsLabel: '${_value.toStringAsFixed(1)} ${_unit.label}',
          ),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppDimens.space4),
          TrackerSummaryLine(parts: facts, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppDimens.sectionGap),
        ValueRuler(
          value: _value,
          min: _unit.minValue.toDouble(),
          max: _unit.maxValue.toDouble(),
          color: _metric.color,
          semanticValue: (v) => '${v.toStringAsFixed(1)} ${_unit.label}',
          onChanged: (v) => setState(() {
            _value = v;
            _error = null;
          }),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: AppDimens.space8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _typed() {
    return AppTextField(
      label: 'Weight',
      controller: _text,
      hint: '0.0',
      suffixText: _unit.label,
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
      onChanged: (_) => setState(() => _error = null),
    );
  }
}
