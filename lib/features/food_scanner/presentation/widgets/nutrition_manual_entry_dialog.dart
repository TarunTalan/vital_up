import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';

class AutocompleteSuggestion {
  final String name;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final bool isOffline;
  final String? fdcId;

  AutocompleteSuggestion({
    required this.name,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.isOffline,
    this.fdcId,
  });
}

class NutritionManualEntryDialog extends StatefulWidget {
  final String barcode;
  final String? initialName;
  final Map<String, double>? parsedNutrition;
  final Function({
    required String name,
    required double quantity,
    required String unit,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double fiberG,
    required double sugarG,
    required double sodiumMg,
  }) onSave;

  const NutritionManualEntryDialog({
    super.key,
    required this.barcode,
    this.initialName,
    this.parsedNutrition,
    required this.onSave,
  });

  @override
  State<NutritionManualEntryDialog> createState() => _NutritionManualEntryDialogState();
}

class _NutritionManualEntryDialogState extends State<NutritionManualEntryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _sugarController;
  late TextEditingController _sodiumController;

  String _selectedUnit = 'g';
  final List<String> _units = ['g', 'serving', 'oz', 'cup', 'piece', 'slice', 'tbsp', 'tsp'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _quantityController = TextEditingController(text: '100');

    // Pre-fill parsed nutrition if available
    final parsed = widget.parsedNutrition;
    _caloriesController = TextEditingController(text: parsed?['calories']?.toStringAsFixed(1) ?? '0');
    _proteinController = TextEditingController(text: parsed?['protein']?.toStringAsFixed(1) ?? '0');
    _carbsController = TextEditingController(text: parsed?['carbs']?.toStringAsFixed(1) ?? '0');
    _fatController = TextEditingController(text: parsed?['fat']?.toStringAsFixed(1) ?? '0');
    _fiberController = TextEditingController(text: parsed?['fiber']?.toStringAsFixed(1) ?? '0');
    _sugarController = TextEditingController(text: parsed?['sugar']?.toStringAsFixed(1) ?? '0');
    _sodiumController = TextEditingController(text: parsed?['sodium']?.toStringAsFixed(1) ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  Future<Iterable<AutocompleteSuggestion>> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      return const [];
    }

    final repository = GetIt.instance<NutritionRepository>();

    // 1. Fetch offline suggestions from Isar (instant)
    final offlineFoods = await repository.searchOfflineFoods(query);
    final offlineSuggestions = offlineFoods.map((f) => AutocompleteSuggestion(
      name: f.name,
      servingSize: f.servingSize,
      calories: f.calories,
      protein: f.proteinG,
      carbs: f.carbsG,
      fat: f.fatG,
      fiber: f.fiberG,
      sugar: f.sugarG,
      sodium: f.sodiumMg,
      isOffline: true,
    )).toList();

    // 2. Fetch online suggestions if connected
    List<AutocompleteSuggestion> onlineSuggestions = [];
    try {
      final searchResult = await repository.searchByName(query);
      searchResult.fold(
        (failure) => null,
        (foodItems) {
          onlineSuggestions = foodItems.map((item) => AutocompleteSuggestion(
            name: item.name,
            servingSize: item.servingDescription,
            calories: 0.0,
            protein: 0.0,
            carbs: 0.0,
            fat: 0.0,
            fiber: 0.0,
            sugar: 0.0,
            sodium: 0.0,
            isOffline: false,
            fdcId: item.id,
          )).toList();
        },
      );
    } catch (_) {}

    // Deduplicate by name (prefer offline local suggestions)
    final Map<String, AutocompleteSuggestion> unique = {};
    for (final suggestion in [...offlineSuggestions, ...onlineSuggestions]) {
      final nameKey = suggestion.name.toLowerCase().trim();
      if (!unique.containsKey(nameKey)) {
        unique[nameKey] = suggestion;
      }
    }

    return unique.values;
  }

  void _onSuggestionSelected(AutocompleteSuggestion suggestion) async {
    setState(() {
      _nameController.text = suggestion.name;
    });

    if (suggestion.isOffline) {
      // Offline suggestion has all macros pre-populated!
      setState(() {
        _quantityController.text = suggestion.servingSize.replaceAll(RegExp(r'[^\d.]'), '');
        if (_quantityController.text.isEmpty) {
          _quantityController.text = '100';
        }
        
        if (suggestion.servingSize.toLowerCase().contains('serving')) {
          _selectedUnit = 'serving';
        } else if (suggestion.servingSize.toLowerCase().contains('piece')) {
          _selectedUnit = 'piece';
        } else {
          _selectedUnit = 'g';
        }

        _caloriesController.text = suggestion.calories.toStringAsFixed(1);
        _proteinController.text = suggestion.protein.toStringAsFixed(1);
        _carbsController.text = suggestion.carbs.toStringAsFixed(1);
        _fatController.text = suggestion.fat.toStringAsFixed(1);
        _fiberController.text = suggestion.fiber.toStringAsFixed(1);
        _sugarController.text = suggestion.sugar.toStringAsFixed(1);
        _sodiumController.text = suggestion.sodium.toStringAsFixed(1);
      });
    } else {
      // Remote suggestion needs details query
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00A6B7))),
      );

      final repository = GetIt.instance<NutritionRepository>();
      final dummyItem = FoodItem(
        id: suggestion.fdcId ?? suggestion.name,
        name: suggestion.name,
        confidenceScore: 1.0,
        servingDescription: suggestion.servingSize,
        quantity: 1.0,
        unit: 'serving',
      );

      final detailResult = await repository.getNutrition(dummyItem);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loader
      }

      detailResult.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load nutritional details for selected item.')),
          );
        },
        (info) {
          setState(() {
            _quantityController.text = info.per.servingDescription.replaceAll(RegExp(r'[^\d.]'), '');
            if (_quantityController.text.isEmpty) {
              _quantityController.text = '100';
            }

            if (info.per.servingDescription.toLowerCase().contains('serving')) {
              _selectedUnit = 'serving';
            } else if (info.per.servingDescription.toLowerCase().contains('piece')) {
              _selectedUnit = 'piece';
            } else {
              _selectedUnit = 'g';
            }

            _caloriesController.text = info.calories.toStringAsFixed(1);
            _proteinController.text = info.proteinG.toStringAsFixed(1);
            _carbsController.text = info.carbsG.toStringAsFixed(1);
            _fatController.text = info.fatG.toStringAsFixed(1);
            _fiberController.text = info.fiberG.toStringAsFixed(1);
            _sugarController.text = info.sugarG.toStringAsFixed(1);
            _sodiumController.text = info.sodiumMg.toStringAsFixed(1);
          });
        },
      );
    }
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final quantity = double.tryParse(_quantityController.text) ?? 100.0;
    final calories = double.tryParse(_caloriesController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;
    final fiber = double.tryParse(_fiberController.text) ?? 0.0;
    final sugar = double.tryParse(_sugarController.text) ?? 0.0;
    final sodium = double.tryParse(_sodiumController.text) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name')),
      );
      return;
    }

    widget.onSave(
      name: name,
      quantity: quantity,
      unit: _selectedUnit,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
      sugarG: sugar,
      sodiumMg: sodium,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dialogBgColor = isDark ? const Color(0xE6121315) : const Color(0xF2FFFFFF);
    final borderColor = isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8);
    final fieldFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    const actionColor = Color(0xFF00A6B7);

    Widget buildField({
      required String label,
      required TextEditingController controller,
      String? suffix,
      TextInputType keyboardType = TextInputType.number,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  suffixText: suffix,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: actionColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: fieldFillColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: dialogBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Icon(
                        widget.parsedNutrition != null ? Icons.document_scanner_outlined : Icons.edit_note_rounded,
                        color: actionColor,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.parsedNutrition != null ? 'Verify Nutrition Label' : 'Enter Product Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Name',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Autocomplete<AutocompleteSuggestion>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            return _fetchSuggestions(textEditingValue.text);
                          },
                          displayStringForOption: (AutocompleteSuggestion option) => option.name,
                          onSelected: _onSuggestionSelected,
                          optionsViewBuilder: (context, onSelected, options) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final bgColor = isDark ? const Color(0xE61E1E24) : const Color(0xF2FFFFFF);
                            final borderColor = isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8);

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                elevation: 4.0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                    child: Container(
                                      width: 320,
                                      constraints: const BoxConstraints(maxHeight: 220),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (BuildContext context, int index) {
                                          final option = options.elementAt(index);
                                          return ListTile(
                                            dense: true,
                                            title: Text(
                                              option.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            subtitle: Text(
                                              option.isOffline ? 'Offline DB • ${option.servingSize}' : 'Cloud Database',
                                              style: TextStyle(
                                                color: option.isOffline ? const Color(0xFF00A6B7) : Colors.grey,
                                                fontSize: 10,
                                              ),
                                            ),
                                            trailing: Icon(
                                              option.isOffline ? Icons.offline_bolt_outlined : Icons.cloud_queue_rounded,
                                              size: 15,
                                              color: option.isOffline ? const Color(0xFF00A6B7) : Colors.grey,
                                            ),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            if (textEditingController.text != _nameController.text) {
                              textEditingController.text = _nameController.text;
                            }
                            textEditingController.addListener(() {
                              _nameController.text = textEditingController.text;
                            });

                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: theme.textTheme.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'e.g., Haldiram\'s Bhujia',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: actionColor, width: 1.5),
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Serving size',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: theme.textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: actionColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: fieldFillColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                style: theme.textTheme.bodyMedium,
                                dropdownColor: dialogBgColor,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: actionColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: fieldFillColor,
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
                        const SizedBox(height: 16),
                        const Text(
                          'Nutrition Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        buildField(label: 'Calories', controller: _caloriesController, suffix: 'kcal'),
                        buildField(label: 'Protein', controller: _proteinController, suffix: 'g'),
                        buildField(label: 'Carbohydrates', controller: _carbsController, suffix: 'g'),
                        buildField(label: 'Fat', controller: _fatController, suffix: 'g'),
                        buildField(label: 'Sugar', controller: _sugarController, suffix: 'g'),
                        buildField(label: 'Dietary Fiber', controller: _fiberController, suffix: 'g'),
                        buildField(label: 'Sodium', controller: _sodiumController, suffix: 'mg'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: actionColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
