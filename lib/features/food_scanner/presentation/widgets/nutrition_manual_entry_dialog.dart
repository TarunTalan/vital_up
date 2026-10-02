import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
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

  /// Cloud search is an edge function call, so it waits for typing to pause
  /// and skips very short prefixes; offline matches show on every keystroke.
  static const Duration _remoteSearchDebounce = Duration(milliseconds: 400);
  static const int _minRemoteQueryLength = 3;

  /// Bumped per keystroke; a cloud search only applies if it is still the latest.
  int _queryGeneration = 0;

  /// Cloud results for this dialog, by normalized query.
  final Map<String, List<AutocompleteSuggestion>> _remoteByQuery = {};

  /// Cloud results for the latest query when they arrive after its offline
  /// matches are already showing; merged into the open options list.
  final ValueNotifier<List<AutocompleteSuggestion>> _lateRemote = ValueNotifier(const []);

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
    _lateRemote.dispose();
    super.dispose();
  }

  Future<Iterable<AutocompleteSuggestion>> _fetchSuggestions(String query) async {
    final generation = ++_queryGeneration;
    _lateRemote.value = const [];
    final normalized = query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return const [];
    }

    final repository = GetIt.instance<NutritionRepository>();

    // 1. Fetch offline suggestions from Isar (instant)
    final offlineFoods = await repository.searchOfflineFoods(normalized);
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

    if (normalized.length < _minRemoteQueryLength) return offlineSuggestions;

    // 2. Online suggestions: already fetched, or debounced in the background
    final known = _remoteByQuery[normalized];
    if (known != null) return _mergeSuggestions(offlineSuggestions, known);

    final remote = _searchRemote(repository, normalized, generation);
    if (offlineSuggestions.isNotEmpty) {
      // Show local matches now; cloud ones join via [_lateRemote].
      remote.then((items) {
        if (mounted && items != null && generation == _queryGeneration) _lateRemote.value = items;
      });
      return offlineSuggestions;
    }
    // Nothing local to show, so wait for the cloud.
    return _mergeSuggestions(offlineSuggestions, await remote ?? const []);
  }

  /// Cloud search for [query] after the debounce. Null if a newer keystroke
  /// superseded it before the request went out.
  Future<List<AutocompleteSuggestion>?> _searchRemote(
    NutritionRepository repository,
    String query,
    int generation,
  ) async {
    await Future<void>.delayed(_remoteSearchDebounce);
    if (!mounted || generation != _queryGeneration) return null;

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
          _remoteByQuery[query] = onlineSuggestions;
        },
      );
    } catch (_) {}
    return onlineSuggestions;
  }

  /// Deduplicates by name, keeping the first (offline suggestions go first).
  static List<AutocompleteSuggestion> _mergeSuggestions(
    Iterable<AutocompleteSuggestion> first,
    Iterable<AutocompleteSuggestion> second,
  ) {
    final Map<String, AutocompleteSuggestion> unique = {};
    for (final suggestion in [...first, ...second]) {
      unique.putIfAbsent(suggestion.name.toLowerCase().trim(), () => suggestion);
    }
    return unique.values.toList();
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
        builder: (context) => Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
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

  String? _nameError;

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
      setState(() => _nameError = 'Enter a product name');
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
    final v = context.vColors;
    final primary = context.colors.primary;

    Widget buildField({
      required String label,
      required TextEditingController controller,
      String? suffix,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.space12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: v.grayText,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.space8),
            Expanded(
              flex: 4,
              child: AppTextField.decimal(
                controller: controller,
                suffixText: suffix,
                hint: '0',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
      );
    }

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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.space20,
                    AppDimens.space20,
                    AppDimens.space20,
                    AppDimens.space12,
                  ),
                  child: Row(
                    children: [
                      AppIconBadge(
                        icon: Icon(
                          widget.parsedNutrition != null ? Icons.document_scanner_outlined : Icons.edit_note_rounded,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Text(
                          widget.parsedNutrition != null ? 'Verify Nutrition Label' : 'Enter Product Details',
                          style: context.text.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Form Fields
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.space20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.inputLabelGap),
                          child: Text('Product Name', style: context.text.titleSmall),
                        ),
                        LayoutBuilder(
                          builder: (context, fieldConstraints) => Autocomplete<AutocompleteSuggestion>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            return _fetchSuggestions(textEditingValue.text);
                          },
                          displayStringForOption: (AutocompleteSuggestion option) => option.name,
                          onSelected: _onSuggestionSelected,
                          optionsViewBuilder: (context, onSelected, options) {
                            final grey = context.vColors.grayText;
                            final divider = context.vColors.divider;

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: fieldConstraints.maxWidth,
                                  constraints: BoxConstraints(
                                    maxHeight: context.hFraction(0.3),
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.vColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                                    border: Border.all(color: context.vColors.hairline!),
                                    boxShadow: AppShadows.elevated,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                                    child: ValueListenableBuilder<List<AutocompleteSuggestion>>(
                                      valueListenable: _lateRemote,
                                      builder: (context, lateRemote, _) {
                                        final shown = lateRemote.isEmpty ? options : _mergeSuggestions(options, lateRemote);
                                        return ListView.separated(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: shown.length,
                                          separatorBuilder: (_, _) => Divider(color: divider),
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = shown.elementAt(index);
                                            final tone = option.isOffline ? primary : grey;
                                            return ListTile(
                                              dense: true,
                                              title: Text(
                                                option.name,
                                                style: context.text.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                option.isOffline ? 'Offline DB • ${option.servingSize}' : 'Cloud Database',
                                                style: context.text.bodySmall?.copyWith(color: tone),
                                              ),
                                              trailing: Icon(
                                                option.isOffline ? Icons.offline_bolt_outlined : Icons.cloud_queue_rounded,
                                                size: AppDimens.iconXs,
                                                color: tone,
                                              ),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        );
                                      },
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

                            return AppTextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              hint: 'e.g., Haldiram\'s Bhujia',
                              error: _nameError,
                              textCapitalization: TextCapitalization.words,
                              onSubmitted: (_) => onFieldSubmitted(),
                              onChanged: (_) {
                                if (_nameError != null) {
                                  setState(() => _nameError = null);
                                }
                              },
                            );
                          },
                        ),
                        ),
                        const SizedBox(height: AppDimens.space16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Serving size', style: context.text.titleSmall),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            Expanded(
                              flex: 2,
                              child: AppTextField.decimal(
                                controller: _quantityController,
                                hint: '1',
                              ),
                            ),
                            const SizedBox(width: AppDimens.space8),
                            Expanded(
                              flex: 2,
                              child: AppDropdownField<String>(
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
                        const SizedBox(height: AppDimens.space16),
                        AppCaption('Nutrition Information', color: primary),
                        const SizedBox(height: AppDimens.space12),
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
                const Divider(),
                // Action buttons
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
                          label: 'Submit',
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
