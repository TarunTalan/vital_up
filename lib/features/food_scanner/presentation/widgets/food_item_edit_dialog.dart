import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/food_scanner/domain/nutrition_sanity.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';

class FoodItemEditDialog extends StatefulWidget {
  final FoodItem? item;
  final Function(String name, double quantity, String unit) onSave;

  const FoodItemEditDialog({
    super.key,
    this.item,
    required this.onSave,
  });

  @override
  State<FoodItemEditDialog> createState() => _FoodItemEditDialogState();
}

class _FoodItemEditDialogState extends State<FoodItemEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  String? _nameError;
  String? _quantityError;
  String _selectedUnit = 'serving';

  final List<String> _units = ['serving', 'g', 'oz', 'cup', 'piece', 'slice', 'tbsp', 'tsp'];

  /// Prevents a double tap from adding the item twice.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    final quantity = widget.item?.quantity;
    _quantityController = TextEditingController(
      text: quantity == null
          ? '1'
          : quantity == quantity.roundToDouble()
              ? quantity.round().toString()
              : quantity.toStringAsFixed(1),
    );
    _selectedUnit = widget.item?.unit ?? 'serving';
    // A unit from the server (e.g. "bowl") must be in the list, or the
    // dropdown asserts.
    if (!_units.contains(_selectedUnit)) _units.insert(0, _selectedUnit);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_submitted) return;
    final name = sanitizeText(_nameController.text, maxLength: InputLimits.shortText);
    final quantity = parseNumberInRange(
      _quantityController.text,
      min: NutritionLimits.quantityMin,
      max: NutritionLimits.quantityMax,
    );

    setState(() {
      _nameError = name.isEmpty ? 'Enter a food name' : null;
      _quantityError = quantity == null
          ? 'Enter an amount from ${NutritionLimits.quantityMin} to ${NutritionLimits.quantityMax.round()}'
          : null;
    });
    if (_nameError != null || quantity == null) return;

    _submitted = true;
    widget.onSave(name, quantity, _selectedUnit);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.glassBlur / 2,
          sigmaY: AppDimens.glassBlur / 2,
        ),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.gutter,
            vertical: AppDimens.space24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusDialog),
            side: BorderSide(color: v.hairline!),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.space20,
                    AppDimens.space20,
                    AppDimens.space20,
                    AppDimens.space12,
                  ),
                  child: Text(
                    widget.item == null ? 'Add Food Item' : 'Edit Food Item',
                    style: context.text.headlineSmall,
                  ),
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.space20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Food Name',
                          controller: _nameController,
                          hint: 'e.g., Grilled Chicken',
                          error: _nameError,
                          maxLength: InputLimits.shortText,
                          inputFormatters: InputFormatters.text(InputLimits.shortText),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppDimens.space16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField.decimal(
                                label: 'Quantity',
                                controller: _quantityController,
                                hint: '1.0',
                                error: _quantityError,
                                onChanged: (_) {
                                  if (_quantityError != null) {
                                    setState(() => _quantityError = null);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimens.space12),
                            Expanded(
                              child: AppDropdownField<String>(
                                label: 'Unit',
                                value: _selectedUnit,
                                items: _units,
                                itemLabel: (unit) => unit,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedUnit = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.space20),
                        const AppInfoNote(
                          message: 'We look up nutrition from the food name.',
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppDimens.space16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Cancel',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: AppDimens.buttonGap),
                      Expanded(
                        child: AppPrimaryButton(
                          label: widget.item == null ? 'Add' : 'Save',
                          onTap: _handleSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Field label — Figma input label (body 16 med), 6dp above the field.
