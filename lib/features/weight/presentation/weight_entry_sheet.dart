import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
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
  late final _value = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_value.text.replaceAll(',', '.'));
    if (value == null) {
      setState(() => _error = 'Enter your weight.');
      return;
    }
    setState(() => _saving = true);
    final error = await sl<WeightService>().add(widget.unit.toKg(value));
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          0,
          context.gutter,
          AppDimens.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Log weight', style: context.text.headlineSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),
            Divider(
              height: AppDimens.borderThin,
              color: context.vColors.divider,
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppTextField.decimal(
              label: 'Weight',
              controller: _value,
              hint: '0.0',
              suffixText: widget.unit.label,
              autofocus: true,
              error: _error,
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppDimens.sectionGap),
            AppPrimaryButton(label: 'Save', isLoading: _saving, onTap: _save),
          ],
        ),
      ),
    );
  }
}
