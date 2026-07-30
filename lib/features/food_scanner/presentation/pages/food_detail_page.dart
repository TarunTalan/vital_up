import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/features/food_scanner/data/models/food_scanner_models.dart';
import 'package:vital_up/features/food_scanner/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/food_item_edit_dialog.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/food_scan_utils.dart';
import 'package:vital_up/features/auth/presentation/widgets/back_icon.dart';
import 'package:vital_up/features/food_scanner/presentation/widgets/accuracy_info_dialog.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

final GetIt _sl = GetIt.instance;

class FoodDetailPage extends StatelessWidget {
  const FoodDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoodScanBloc, FoodScanState>(
      listenWhen: (previous, current) =>
          current is MealLogSaved || current is RecognitionFailed,
      listener: (context, state) {
        if (state is MealLogSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal saved to your log.')),
          );
          Navigator.of(context).maybePop();
        } else if (state is RecognitionFailed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failure.message)));
        }
      },
      builder: (context, state) {
        // Show loading overlay when fetching nutrition for manual items
        if (state is LoadingNutrition) {
          return Stack(
            children: [
              _buildContent(context, state),
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }
        return _buildContent(context, state);
      },
    );
  }

  Widget _buildContent(BuildContext context, FoodScanState state) {
    final data = _FoodDetailData.fromState(state);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _FoodScannerStyle.onBackground,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: BackIcon(
              onClick: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.ios_share_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              showSmoothDialog(
                context: context,
                builder: (context) => const AccuracyInfoDialog(),
              );
            },
            icon: Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          if (data == null)
            const Center(child: Text('No nutrition data available.'))
          else
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  _FoodScannerStyle.paddingLarge,
                  _FoodScannerStyle.paddingSmall,
                  _FoodScannerStyle.paddingLarge,
                  _FoodScannerStyle.paddingLarge,
                ),
                children: [
                  _ScannedDish(
                    imagePath: data.imagePath,
                    onEditImage: () {
                      final bloc = context.read<FoodScanBloc>();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BlocProvider<FoodScanBloc>.value(
                            value: bloc,
                            child: const FoodScannerPage(isEditingImage: true),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: _FoodScannerStyle.rowSpacing),
                  _KeyMatrices(data: data),
                  const SizedBox(height: _FoodScannerStyle.rowSpacing),
                  _DishInfoCard(
                    dishes: data.dishes,
                    foodItems: data.foodItems,
                    onRemove: (id) {
                      context.read<FoodScanBloc>().add(
                        RemoveDetectedItemRequested(id),
                      );
                    },
                    onEdit: (itemId, name, quantity, unit) {
                      context.read<FoodScanBloc>().add(
                        EditFoodItemRequested(
                          itemId: itemId,
                          name: name,
                          quantity: quantity,
                          unit: unit,
                        ),
                      );
                    },
                    onAdd: (name, quantity, unit) {
                      context.read<FoodScanBloc>().add(
                        AddManualItemRequested(
                          name: name,
                          quantity: quantity,
                          unit: unit,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: _FoodScannerStyle.rowSpacing),
                  _MacroCard(
                    macros: data.macros,
                    details: data.macroDetails,
                    totalGrams: data.totalMacroGrams,
                  ),
                  if (data.mealInfo != null) ...[
                    const SizedBox(height: _FoodScannerStyle.rowSpacing),
                    _MealInfoPopup(data: data.mealInfo!),
                  ],
                  if (data.suggestions.isNotEmpty) ...[
                    const SizedBox(height: _FoodScannerStyle.rowSpacing),
                    _Suggestions(suggestions: data.suggestions),
                  ],
                  const SizedBox(height: _FoodScannerStyle.rowSpacing),
                  _SaveButton(
                    isSaving: state is SavingMealLog,
                    onSave: () {
                      context.read<FoodScanBloc>().add(
                        ConfirmAndSaveRequested(data.mealType),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodDetailData {
  final String? imagePath;
  final String dishName;
  final int totalCalories;
  final int healthScore;
  final List<DishItem> dishes;
  final List<FoodItem> foodItems;
  final List<MacroMain> macros;
  final List<MacroDetail> macroDetails;
  final int totalMacroGrams;
  final MealType mealType;
  final MealPopupData? mealInfo;
  final List<String> suggestions;

  const _FoodDetailData({
    required this.imagePath,
    required this.dishName,
    required this.totalCalories,
    required this.healthScore,
    required this.dishes,
    required this.foodItems,
    required this.macros,
    required this.macroDetails,
    required this.totalMacroGrams,
    required this.mealType,
    required this.mealInfo,
    required this.suggestions,
  });

  static _FoodDetailData? fromState(FoodScanState state) {
    File? image;
    List<FoodItem> items;
    List<NutritionInfo> nutrition;

    if (state is RecognitionSucceeded) {
      image = state.image;
      items = state.items;
      nutrition = state.nutrition;
    } else if (state is RecognitionLowConfidence) {
      image = state.image;
      items = state.items;
      nutrition = state.nutrition;
    } else if (state is NutritionLoaded) {
      image = state.image;
      items = state.items;
      nutrition = state.nutrition;
    } else if (state is LoadingNutrition) {
      image = state.image;
      items = state.items;
      nutrition = state.nutrition;
    } else {
      return null;
    }

    if (items.isEmpty || nutrition.isEmpty) return null;
    
    // Handle null image case for manual entry without image
    if (image == null) {
      // For manual entries without an image, we'll skip the image display
      // but still show the nutrition data
    }

    final totalCalories = FoodScanUtils.calculateTotalCalories(nutrition);
    final totalProtein = FoodScanUtils.calculateTotalProtein(nutrition);
    final totalCarbs = FoodScanUtils.calculateTotalCarbs(nutrition);
    final totalFat = FoodScanUtils.calculateTotalFat(nutrition);
    final totalFiber = nutrition.fold<double>(
      0,
      (sum, nut) => sum + nut.fiberG,
    );
    final totalSugar = nutrition.fold<double>(
      0,
      (sum, nut) => sum + nut.sugarG,
    );
    final totalSodium = nutrition.fold<double>(
      0,
      (sum, nut) => sum + nut.sodiumMg,
    );

    final dishes = [
      for (final nut in nutrition)
        DishItem(
          id: nut.per.id,
          name: nut.per.name,
          calories: nut.calories.round(),
        ),
    ];

    final totalSaturatedFat = nutrition.fold<double>(0, (sum, nut) => sum + nut.saturatedFatG);
    final totalTransFat = nutrition.fold<double>(0, (sum, nut) => sum + nut.transFatG);
    final totalCholesterol = nutrition.fold<double>(0, (sum, nut) => sum + nut.cholesterolMg);
    final totalPotassium = nutrition.fold<double>(0, (sum, nut) => sum + nut.potassiumMg);
    final totalCalcium = nutrition.fold<double>(0, (sum, nut) => sum + nut.calciumMg);
    final totalIron = nutrition.fold<double>(0, (sum, nut) => sum + nut.ironMg);
    final totalVitaminC = nutrition.fold<double>(0, (sum, nut) => sum + nut.vitaminCMg);
    final totalVitaminD = nutrition.fold<double>(0, (sum, nut) => sum + nut.vitaminDIu);
    final totalVitaminB12 = nutrition.fold<double>(0, (sum, nut) => sum + nut.vitaminB12Mcg);
    final totalMagnesium = nutrition.fold<double>(0, (sum, nut) => sum + nut.magnesiumMg);
    final totalZinc = nutrition.fold<double>(0, (sum, nut) => sum + nut.zincMg);

    final candidates = [
      _NutrientCandidate(name: 'Carbs', value: totalCarbs, unit: 'g', color: const Color(0xFFFFB300)),
      _NutrientCandidate(name: 'Protein', value: totalProtein, unit: 'g', color: const Color(0xFF00B3A4)),
      _NutrientCandidate(name: 'Fat', value: totalFat, unit: 'g', color: const Color(0xFF9C7CFF)),
    ];

    final top3 = candidates;
    final totalTop3Weight = top3.fold<double>(0, (sum, item) => sum + item.value);

    final macros = top3.map((item) {
      final pct = totalTop3Weight > 0 ? (item.value / totalTop3Weight * 100).round() : 0;
      return MacroMain(
        name: item.name,
        grams: item.value.round(),
        percent: pct,
        color: item.color,
      );
    }).toList();

    final macroDetails = <MacroDetail>[];
    
    // --- 1. Common Healthy Macros/Nutrients ---
    if (totalFiber > 0) {
      macroDetails.add(MacroDetail(name: 'Dietary Fiber', grams: totalFiber, unit: 'g'));
    }
    if (totalPotassium > 0) {
      macroDetails.add(MacroDetail(name: 'Potassium', grams: totalPotassium, unit: 'mg'));
    }
    if (totalCalcium > 0) {
      macroDetails.add(MacroDetail(name: 'Calcium', grams: totalCalcium, unit: 'mg'));
    }
    if (totalIron > 0) {
      macroDetails.add(MacroDetail(name: 'Iron', grams: totalIron, unit: 'mg'));
    }
    if (totalVitaminC > 0) {
      macroDetails.add(MacroDetail(name: 'Vitamin C', grams: totalVitaminC, unit: 'mg'));
    }

    // --- 2. Rare but Important Healthy Nutrients ---
    if (totalVitaminD > 0) {
      macroDetails.add(MacroDetail(name: 'Vitamin D', grams: totalVitaminD, unit: 'IU'));
    }
    if (totalVitaminB12 > 0) {
      macroDetails.add(MacroDetail(name: 'Vitamin B12', grams: totalVitaminB12, unit: 'mcg'));
    }
    if (totalMagnesium > 0) {
      macroDetails.add(MacroDetail(name: 'Magnesium', grams: totalMagnesium, unit: 'mg'));
    }
    if (totalZinc > 0) {
      macroDetails.add(MacroDetail(name: 'Zinc', grams: totalZinc, unit: 'mg'));
    }

    // --- 3. Unhealthy/Harmful Macros/Nutrients ---
    if (totalSugar > 0) {
      macroDetails.add(MacroDetail(name: 'Total Sugars', grams: totalSugar, unit: 'g'));
    }
    if (totalSaturatedFat > 0) {
      macroDetails.add(MacroDetail(name: 'Saturated Fat', grams: totalSaturatedFat, unit: 'g'));
    }
    if (totalTransFat > 0) {
      macroDetails.add(MacroDetail(name: 'Trans Fat', grams: totalTransFat, unit: 'g'));
    }
    if (totalCholesterol > 0) {
      macroDetails.add(MacroDetail(name: 'Cholesterol', grams: totalCholesterol, unit: 'mg'));
    }
    if (totalSodium > 0) {
      macroDetails.add(MacroDetail(name: 'Sodium', grams: totalSodium, unit: 'mg'));
    }

    // Sort all details in descending order of their weight contribution (converting all to grams)
    double getWeightInGrams(MacroDetail detail) {
      switch (detail.unit.toLowerCase()) {
        case 'g':
          return detail.grams;
        case 'mg':
          return detail.grams / 1000.0;
        case 'mcg':
          return detail.grams / 1000000.0;
        case 'iu':
          return detail.grams * 0.000000025; // 1 IU Vitamin D = 0.025 mcg = 0.000000025 g
        default:
          return detail.grams;
      }
    }
    macroDetails.sort((a, b) => getWeightInGrams(b).compareTo(getWeightInGrams(a)));

    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    final rawDishName = items.length == 1 ? items.first.name : 'Scanned Meal';
    final dishName = capitalize(rawDishName);
    final now = DateTime.now();
    final mealType = MealLogEntry.mealTypeFromTime(now);

    final recommendation = _buildRecommendation(
      image: image,
      items: items,
      nutrition: nutrition,
      totalCalories: totalCalories,
      mealType: mealType,
      now: now,
    );

    final mealInfo = MealPopupData(
      title: _mealTypeLabel(mealType),
      time: _formatTime(now),
      points: recommendation == null || recommendation.message.isEmpty
          ? const []
          : [recommendation.message],
    );

    final totalMacronutrientsWeight = totalProtein + totalCarbs + totalFat;
    final totalMacroWeight = candidates.fold<double>(0, (sum, item) => sum + item.value);

    return _FoodDetailData(
      imagePath: image?.path,
      dishName: dishName,
      totalCalories: totalCalories.round(),
      healthScore: _computeHealthScore(
        totalCalories: totalCalories,
        proteinRatio: totalProtein / (totalMacronutrientsWeight > 0 ? totalMacronutrientsWeight : 1),
        carbRatio: totalCarbs / (totalMacronutrientsWeight > 0 ? totalMacronutrientsWeight : 1),
        fatRatio: totalFat / (totalMacronutrientsWeight > 0 ? totalMacronutrientsWeight : 1),
        fiberG: totalFiber,
        sugarG: totalSugar,
        sodiumMg: totalSodium,
        saturatedFatG: totalSaturatedFat,
        transFatG: totalTransFat,
        cholesterolMg: totalCholesterol,
        foodNames: items.map((item) => item.name).toList(),
      ),
      dishes: dishes,
      foodItems: items,
      macros: macros,
      macroDetails: macroDetails,
      totalMacroGrams: totalMacroWeight.round(),
      mealType: mealType,
      mealInfo: mealInfo.points.isEmpty ? null : mealInfo,
      suggestions: recommendation == null
          ? const []
          : _tagsToSuggestions(recommendation.reasonTags),
    );
  }
}

_Recommendation? _buildRecommendation({
  required File? image,
  required List<FoodItem> items,
  required List<NutritionInfo> nutrition,
  required double totalCalories,
  required MealType mealType,
  required DateTime now,
}) {
  if (!_sl.isRegistered<GetMealRecommendation>()) return null;
  final entry = MealLogEntry(
    id: 'preview',
    capturedAt: now,
    imagePath: image?.path ?? '',
    items: items,
    nutrition: nutrition,
    totalCalories: totalCalories,
    mealType: mealType,
    userConfirmed: false,
  );
  final recommendation = _sl<GetMealRecommendation>()(entry, now: now);
  return _Recommendation(
    message: recommendation.message,
    reasonTags: recommendation.reasonTags,
  );
}

class _Recommendation {
  final String message;
  final List<String> reasonTags;

  const _Recommendation({required this.message, required this.reasonTags});
}

List<String> _tagsToSuggestions(List<String> tags) {
  const mapping = {
    'high_protein':
        'This meal is protein-rich, which supports muscle maintenance and satiety.',
    'high_fat':
        'This meal is high in fat, so balance it with lighter meals today.',
    'late_eating':
        'It is getting late; try to finish eating a couple of hours before bed.',
    'post_workout_window':
        'Great post-workout timing for recovery and muscle repair.',
  };
  return [
    for (final tag in tags)
      if (mapping.containsKey(tag)) mapping[tag]!,
  ];
}

String _mealTypeLabel(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'Breakfast';
    case MealType.lunch:
      return 'Lunch';
    case MealType.dinner:
      return 'Dinner';
    case MealType.snack:
      return 'Snack';
  }
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

int _computeHealthScore({
  required double totalCalories,
  required double proteinRatio,
  required double carbRatio,
  required double fatRatio,
  required double fiberG,
  required double sugarG,
  required double sodiumMg,
  required double saturatedFatG,
  required double transFatG,
  required double cholesterolMg,
  required List<String> foodNames,
}) {
  // 1. Calculate Essential/Good macros score (0 to 100)
  // Protein (target >= 20% of macros)
  final proteinPoints = (proteinRatio * 200.0).clamp(0.0, 50.0);
  // Fiber (target >= 3g per serving or generally high fiber)
  final fiberPoints = (fiberG * 5.0).clamp(0.0, 50.0);
  final essentialScore = proteinPoints + fiberPoints;

  // 2. Calculate Bad/Harmful macros score (0 to 100)
  // Sugar (apply discount if fiber is present to offset natural fruit sugars)
  double adjustedSugar = sugarG;
  if (fiberG > 0 && sugarG > 0) {
    final fiberToSugarRatio = fiberG / (sugarG * 0.2); // 1:5 target ratio
    final discount = fiberToSugarRatio.clamp(0.0, 0.8); // Up to 80% discount for high fiber
    adjustedSugar = sugarG * (1.0 - discount);
  }
  final sugarPoints = (adjustedSugar * 1.0).clamp(0.0, 30.0);
  // Sodium (target < 140mg, penalize above that)
  final sodiumPoints = (sodiumMg / 15.0).clamp(0.0, 30.0);
  // Saturated Fat (target < 4g)
  final satFatPoints = (saturatedFatG * 4.0).clamp(0.0, 20.0);
  // Trans Fat (extremely bad, immediate penalty)
  final transFatPoints = (transFatG * 20.0).clamp(0.0, 10.0);
  final badScore = sugarPoints + sodiumPoints + satFatPoints + transFatPoints;

  // 3. Compute continuous health score based on the user's buckets:
  // - High essential + Low bad => High rating (>= 80)
  // - Low essential + Low bad => Medium rating (55 to 70)
  // - High bad (or low essential + high bad) => Low rating (< 50)
  
  double score = 65.0; // Start at a neutral medium base
  
  // Add positive influence from essential macros
  score += essentialScore * 0.4;
  
  // Subtract negative influence from bad macros (heavier weight to make sure bad items drop to low rating)
  score -= badScore * 1.1;

  // Keyword-based Junk Food Penalty
  bool isJunkFood(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sweet potato') ||
        lower.contains('stir fried') ||
        lower.contains('stir-fried') ||
        lower.contains('pan fried') ||
        lower.contains('pan-fried')) {
      return false;
    }
    final keywords = [
      'fried', 'samosa', 'fries', 'gulab jamun', 'ice cream', 
      'burger', 'pizza', 'donut', 'crisps', 'chips', 'soda', 'coke', 
      'candy', 'sweet', 'cake', 'waffle', 'chocolate', 'nugget', 
      'hot dog', 'hotdog', 'milkshake', 'cookie', 'brownie', 'pastry',
      'syrup', 'jalebi', 'ladoo', 'barfi'
    ];
    return keywords.any((k) => lower.contains(k));
  }

  final junkCount = foodNames.where(isJunkFood).length;
  score -= junkCount * 25.0; // Strong penalty for recognized junk foods

  return score.clamp(1.0, 100.0).round();
}

class _FoodScannerStyle {
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color divider = Color(0x1A000000);
  static const Color track = Color(0x1A000000);
  static const Color cardBg = Color(0x21BABABA);
  static const Color borderLight = Color(0xFFD8D8D8);
  static const Color borderDark = Color(0xFF343434);
  static const Color tealText = Color(0xFF0F7586);
  static const Color action = Color(0xFF00A6B7);
  static const Color numberBorder = Color(0xFF149CB3);
  static const Color scorePurple = Color(0xFF9B59FF);
  static const Color scoreGreen = Color(0xFF2ECC71);
  static const Color scoreYellow = Color(0xFFFFC107);
  static const Color scoreRed = Color(0xFFE74C3C);
  static const Color scoreDarkRed = Color(0xFFB71C1C);

  static const double paddingLarge = 20;
  static const double paddingMedium = 16;
  static const double paddingSmall = 12;
  static const double rowSpacing = 16;
  static const double cardRadius = 20;
  static const double meterSize = 120;
  static const double meterStroke = 12;
  static const double textSmall = 14;
  static const double textMedium = 16;
  static const double textLarge = 18;
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_FoodScannerStyle.paddingMedium),
      decoration: BoxDecoration(
        color: _FoodScannerStyle.cardBg,
        borderRadius: BorderRadius.circular(_FoodScannerStyle.cardRadius),
        border: Border.all(color: _scannerBorderColor(context)),
      ),
      child: child,
    );
  }
}

class _ScannedDish extends StatelessWidget {
  final String? imagePath;
  final VoidCallback? onEditImage;

  const _ScannedDish({this.imagePath, this.onEditImage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (imagePath != null && imagePath!.isNotEmpty)
              Image.file(
                File(imagePath!),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              )
            else
              Container(
                height: 180,
                color: _FoodScannerStyle.cardBg,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 64,
                  color: Color(0xFF1C1C1C),
                ),
              ),
            if (onEditImage != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onEditImage,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyMatrices extends StatelessWidget {
  final _FoodDetailData data;

  const _KeyMatrices({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Key Matrices'),
          const SizedBox(height: 10),
          Text(
            data.dishName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: _FoodScannerStyle.textMedium,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _CircularScoreMeter(score: data.healthScore),
              const SizedBox(width: _FoodScannerStyle.rowSpacing),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Total Calories',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _FoodScannerStyle.tealText,
                        fontSize: 12,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: _FoodScannerStyle.textLarge,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(text: '${data.totalCalories}'),
                          const TextSpan(
                            text: ' Kcal',
                            style: TextStyle(
                              color: _FoodScannerStyle.tealText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularScoreMeter extends StatelessWidget {
  final int score;

  const _CircularScoreMeter({required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100).toInt();
    final color = _scoreColor(clamped);
    final label = _scoreLabel(clamped);

    return SizedBox(
      width: _FoodScannerStyle.meterSize,
      height: _FoodScannerStyle.meterSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: _FoodScannerStyle.meterStroke,
              color: color,
              backgroundColor: _FoodScannerStyle.track,
              strokeCap: StrokeCap.round,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$clamped',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DishInfoCard extends StatelessWidget {
  final List<DishItem> dishes;
  final List<FoodItem> foodItems;
  final ValueChanged<String> onRemove;
  final Function(String itemId, String name, double quantity, String unit)? onEdit;
  final Function(String name, double quantity, String unit)? onAdd;

  const _DishInfoCard({
    required this.dishes,
    required this.foodItems,
    required this.onRemove,
    this.onEdit,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1C1C1C);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Dish Info')),
              InkWell(
                onTap: () => _showAddDialog(context),
                child: Text(
                  'Add +',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _FoodScannerStyle.action,
                    fontSize: _FoodScannerStyle.textSmall,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _FoodScannerStyle.paddingSmall),
          for (final dish in dishes) ...[
            (() {
              // Find the corresponding FoodItem to get portion details
              final foodItem = foodItems.firstWhere(
                (item) => item.id == dish.id,
                orElse: () => FoodItem(
                  id: dish.id,
                  name: dish.name,
                  confidenceScore: 1.0,
                  servingDescription: '1 serving',
                  quantity: 1.0,
                  unit: 'serving',
                ),
              );

              // Helper to compute weight in grams
              double getWeightInGrams(double qty, String unit) {
                switch (unit.toLowerCase()) {
                  case 'g':
                    return qty;
                  case 'oz':
                    return qty * 28.35;
                  case 'cup':
                    return qty * 240;
                  case 'piece':
                  case 'slice':
                    return qty * 50;
                  case 'tbsp':
                    return qty * 15;
                  case 'tsp':
                    return qty * 5;
                  default:
                    return qty * 100;
                }
              }

              final totalWeight = getWeightInGrams(foodItem.quantity, foodItem.unit);
              final qtyStr = foodItem.quantity == foodItem.quantity.roundToDouble()
                  ? foodItem.quantity.round().toString()
                  : foodItem.quantity.toStringAsFixed(1);
              final weightStr = totalWeight == totalWeight.roundToDouble()
                  ? totalWeight.round().toString()
                  : totalWeight.toStringAsFixed(1);

              final subtitleText = foodItem.unit.toLowerCase() == 'g'
                  ? '${qtyStr} g'
                  : '${qtyStr} ${foodItem.unit} (~${weightStr}g)';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: _FoodScannerStyle.textMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontSize: _FoodScannerStyle.textSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${dish.calories} kcal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: _FoodScannerStyle.textSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _showEditDialog(context, dish),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => onRemove(dish.id),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              );
            })(),
          ],
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FoodItemEditDialog(
        onSave: (name, quantity, unit) {
          if (onAdd != null) {
            onAdd!(name, quantity, unit);
          }
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, DishItem dish) {
    // Find the corresponding FoodItem to get current values
    final foodItem = foodItems.firstWhere(
      (item) => item.id == dish.id,
      orElse: () => FoodItem(
        id: dish.id,
        name: dish.name,
        confidenceScore: 1.0,
        servingDescription: '1 serving',
        quantity: 1.0,
        unit: 'serving',
      ),
    );

    showDialog(
      context: context,
      builder: (context) => FoodItemEditDialog(
        item: foodItem,
        onSave: (name, quantity, unit) {
          if (onEdit != null) {
            onEdit!(dish.id, name, quantity, unit);
          }
        },
      ),
    );
  }
}

class _MacroCard extends StatefulWidget {
  final List<MacroMain> macros;
  final List<MacroDetail> details;
  final int totalGrams;

  const _MacroCard({
    required this.macros,
    required this.details,
    required this.totalGrams,
  });

  @override
  State<_MacroCard> createState() => _MacroCardState();
}

class _MacroCardState extends State<_MacroCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMore = widget.details.length > 5;
    final visibleDetails = _isExpanded ? widget.details : widget.details.take(5).toList();

    final totalGrams = widget.macros.fold<double>(0, (sum, m) => sum + m.grams) +
        widget.details
            .where((d) => d.unit.toLowerCase() == 'g')
            .fold<double>(0, (sum, d) => sum + d.grams);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Macros')),
              if (hasMore)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        _isExpanded ? 'Less Details' : 'More Details',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _FoodScannerStyle.action,
                          fontSize: _FoodScannerStyle.textSmall,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF1C1C1C),
                        size: 18,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final macro in widget.macros) ...[
            _MacroMainRow(macro),
            const SizedBox(height: 14),
          ],
          if (visibleDetails.isNotEmpty) ...[
            const Divider(height: 32, color: _FoodScannerStyle.divider),
            for (final detail in visibleDetails) ...[
              _MacroDetailRow(detail),
              const SizedBox(height: 10),
            ],
          ],
          const Divider(height: 32, color: _FoodScannerStyle.divider),
          Text(
            'Total: ${totalGrams.round()}g of macronutrients',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontSize: _FoodScannerStyle.textSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroMainRow extends StatelessWidget {
  final MacroMain macro;

  const _MacroMainRow(this.macro);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                macro.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: _FoodScannerStyle.textLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${macro.grams} g (${macro.percent}%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: _FoodScannerStyle.textMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (macro.percent / 100).clamp(0.0, 1.0),
          minHeight: 8,
          color: macro.color,
          backgroundColor: _FoodScannerStyle.track,
          borderRadius: BorderRadius.circular(50),
        ),
      ],
    );
  }
}

class _MacroDetailRow extends StatelessWidget {
  final MacroDetail detail;

  const _MacroDetailRow(this.detail);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.85);

    final gramsStr = detail.grams == detail.grams.roundToDouble()
        ? detail.grams.round().toString()
        : detail.grams.toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: Text(
            detail.name,
            style: TextStyle(
              color: color,
              fontSize: _FoodScannerStyle.textMedium,
            ),
          ),
        ),
        Text(
          '$gramsStr ${detail.unit}',
          style: TextStyle(
            color: color,
            fontSize: _FoodScannerStyle.textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MealInfoPopup extends StatelessWidget {
  final MealPopupData data;

  const _MealInfoPopup({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF1C1C1C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: _FoodScannerStyle.textMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      data.time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _FoodScannerStyle.subtleText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: colors.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          for (final point in data.points) _BulletText(point),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final List<String> suggestions;

  const _Suggestions({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFF1C1C1C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggestions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: _FoodScannerStyle.textMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: colors.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          for (var i = 0; i < suggestions.length; i++) ...[
            _SuggestionRow(number: i + 1, text: suggestions[i]),
            if (i != suggestions.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveButton({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: isSaving ? null : onSave,
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Add to Log'),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final int number;
  final String text;

  const _SuggestionRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NumberIcon(number),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.2),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: Color(0xFF1C1C1C),
        ),
      ],
    );
  }
}

class _NumberIcon extends StatelessWidget {
  final int number;

  const _NumberIcon(this.number);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _FoodScannerStyle.numberBorder),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: _FoodScannerStyle.numberBorder,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey,
        fontSize: _FoodScannerStyle.textSmall,
      ),
    );
  }
}

Color _scannerBorderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? _FoodScannerStyle.borderDark
      : _FoodScannerStyle.borderLight;
}

Color _scoreColor(int score) {
  if (score >= 85) return _FoodScannerStyle.scorePurple;
  if (score >= 70) return _FoodScannerStyle.scoreGreen;
  if (score >= 55) return _FoodScannerStyle.scoreYellow;
  if (score >= 40) return _FoodScannerStyle.scoreRed;
  return _FoodScannerStyle.scoreDarkRed;
}

String _scoreLabel(int score) {
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Good';
  if (score >= 55) return 'Fair';
  if (score >= 40) return 'Low';
  return 'Poor';
}

class _NutrientCandidate {
  final String name;
  final double value;
  final String unit;
  final Color color;

  const _NutrientCandidate({
    required this.name,
    required this.value,
    required this.unit,
    required this.color,
  });
}
