import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
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
  String _selectedUnit = 'serving';

  final List<String> _units = ['serving', 'g', 'oz', 'cup', 'piece', 'slice', 'tbsp', 'tsp'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '1',
    );
    _selectedUnit = widget.item?.unit ?? 'serving';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a food name')),
      );
      return;
    }

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

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
                        const _FieldLabel('Food Name'),
                        TextField(
                          controller: _nameController,
                          style: context.text.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'e.g., Grilled Chicken',
                          ),
                        ),
                        const SizedBox(height: AppDimens.space16),
                        const _FieldLabel('Quantity'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: context.text.bodyLarge,
                                decoration: const InputDecoration(
                                  hintText: '1.0',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.space12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedUnit,
                                isExpanded: true,
                                style: context.text.bodyLarge,
                                dropdownColor: v.surfaceElevated,
                                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: v.grayText,
                                ),
                                items: _units.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUnit = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.space20),
                        const AppInfoNote(
                          message: 'Nutrition data will be fetched from USDA database based on the food name.',
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
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.inputLabelGap),
      child: Text(text, style: context.text.titleSmall),
    );
  }
}
