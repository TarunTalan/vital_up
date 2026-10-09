import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
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
          current is MealLogSaved || current is RecognitionFailed || current is ScanActionFailed,
      listener: (context, state) {
        if (state is MealLogSaved) {
          showSuccessSnackBar(context, 'Meal saved to your log.');
          Navigator.of(context).maybePop();
        } else if (state is RecognitionFailed) {
          showErrorSnackBar(context, state.failure.message);
        } else if (state is ScanActionFailed) {
          showErrorSnackBar(context, state.failure.message);
        }
      },
      builder: (context, state) {
        // Show loading overlay when fetching nutrition for manual items
        if (state is LoadingNutrition) {
          return Stack(
            children: [
              _buildContent(context, state),
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.black.withValues(alpha: 0.54),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
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
    final topBar = _DetailTopBar(
      onBack: () => Navigator.of(context).maybePop(),
      onShare: () {},
      onInfo: () {
        showSmoothDialog(
          context: context,
          builder: (context) => const AccuracyInfoDialog(),
        );
      },
    );
    final bodyPadding = EdgeInsets.fromLTRB(
      context.gutter,
      AppDimens.space16,
      context.gutter,
      AppDimens.sectionGap,
    );

    if (data == null) {
      return AppScaffold(
        scrollable: false,
        bodyPadding: bodyPadding,
        body: Column(
          children: [
            topBar,
            Expanded(
              child: Center(
                child: Text(
                  'No food to show. Go back and scan again.',
                  style: context.text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      bodyPadding: bodyPadding,
      bottomBar: AppPrimaryButton(
        label: 'Add to Log',
        isLoading: state is SavingMealLog,
        onTap: () {
          // The bloc also ignores repeats, but don't queue them at all.
          if (state is SavingMealLog || state is LoadingNutrition) return;
          context.read<FoodScanBloc>().add(
            ConfirmAndSaveRequested(data.mealType),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topBar,
          const SizedBox(height: AppDimens.space16),
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
          const SizedBox(height: AppDimens.cardInnerGap),
          _KeyMatrices(data: data),
          const SizedBox(height: AppDimens.cardInnerGap),
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
          const SizedBox(height: AppDimens.cardInnerGap),
          _MacroCard(
            macros: data.macros,
            details: data.macroDetails,
            totalGrams: data.totalMacroGrams,
          ),
          if (data.mealInfo != null) ...[
            const SizedBox(height: AppDimens.cardInnerGap),
            _MealInfoPopup(data: data.mealInfo!),
          ],
          if (data.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppDimens.cardInnerGap),
            _Suggestions(suggestions: data.suggestions),
          ],
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
    } else if (state is SavingMealLog) {
      // Keep the meal on screen while it saves.
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
      _NutrientCandidate(name: 'Carbs', value: totalCarbs, unit: 'g', color: AppColors.scanCarbs),
      _NutrientCandidate(name: 'Protein', value: totalProtein, unit: 'g', color: AppColors.scanProtein),
      _NutrientCandidate(name: 'Fat', value: totalFat, unit: 'g', color: AppColors.scanFat),
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
    'high_sodium':
        'High in salt; go easy on pickle, papad and added salt today.',
    'high_sugar':
        'High in sugar; keep your next snack or drink unsweetened.',
    'high_saturated_fat':
        'Much of the fat is saturated (ghee, butter, cream, frying); try a lighter tadka next time.',
    'low_protein':
        'Add dal, curd, paneer, eggs or sprouts to raise the protein.',
    'low_fiber':
        'Add a salad, sabzi or fruit, or choose whole-wheat roti, for more fibre.',
    'high_fiber':
        'Good fibre content helps digestion and keeps you full longer.',
    'large_meal':
        'This is a large meal; keep the next one light.',
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

/// Link-style accent used for "Add +" / "More Details" — Figma #149CB3.
Color _accentText(BuildContext context) =>
    context.isDark ? context.colors.primary : AppColors.primaryActive;

/// Top row — back button plus circular share / info actions.
class _DetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onInfo;

  const _DetailTopBar({
    required this.onBack,
    required this.onShare,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BackIcon(onClick: onBack),
        const Spacer(),
        _CircleIconButton(
          asset: 'assets/icons/share.svg',
          tooltip: 'Share',
          onTap: onShare,
        ),
        const SizedBox(width: AppDimens.space12),
        _CircleIconButton(
          asset: 'assets/icons/info_icon.svg',
          tooltip: 'How accurate is this?',
          onTap: onInfo,
        ),
      ],
    );
  }
}

/// Figma `button/ ArrowLeft` shell reused for header actions.
class _CircleIconButton extends StatelessWidget {
  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: AppDimens.backButtonSize,
        height: AppDimens.backButtonSize,
        decoration: BoxDecoration(
          color: context.vColors.backButtonFill,
          shape: BoxShape.circle,
          boxShadow: AppShadows.shadowY,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: AppDimens.iconLg,
                height: AppDimens.iconLg,
                colorFilter: ColorFilter.mode(
                  context.colors.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannedDish extends StatelessWidget {
  final String? imagePath;
  final VoidCallback? onEditImage;

  const _ScannedDish({this.imagePath, this.onEditImage});

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.w(200)),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.file(File(imagePath!), fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: context.vColors.glassFill!,
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: AppDimens.iconBadgeLarge,
                      color: context.colors.onSurface,
                    ),
                  ),
                if (onEditImage != null)
                  Positioned(
                    right: AppDimens.space8,
                    bottom: AppDimens.space8,
                    child: FoodImageActionPill(onEdit: onEditImage!),
                  ),
              ],
            ),
          ),
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
    final calorieAccent = context.colors.onPrimaryContainer;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Key Metrics'),
          const SizedBox(height: AppDimens.space12),
          Text(
            data.dishName,
            style: context.text.headlineSmall?.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: AppDimens.space16),
          Row(
            children: [
              _CircularScoreMeter(score: data.healthScore),
              const SizedBox(width: AppDimens.space16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Total Calories',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: calorieAccent,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${data.totalCalories}',
                              style: AppTextStyles.metric.copyWith(
                                color: context.colors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: ' Kcal',
                              style: context.text.bodyLarge?.copyWith(
                                color: calorieAccent,
                              ),
                            ),
                          ],
                        ),
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

/// Figma `color grades` ring (GOOD / MOD / BAD).
class _CircularScoreMeter extends StatelessWidget {
  final int score;

  const _CircularScoreMeter({required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100).toInt();
    final color = _scoreColor(clamped);
    final label = _scoreLabel(clamped);
    final size = context.w(AppDimens.scoreMeterSize);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: AppDimens.scoreMeterStroke,
              color: color,
              backgroundColor: context.vColors.track,
              strokeCap: StrokeCap.round,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              AppDimens.scoreMeterStroke + AppDimens.space8,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clamped',
                    style: context.text.headlineLarge?.copyWith(color: color),
                  ),
                  Text(
                    label,
                    style: context.text.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
    final accent = _accentText(context);
    final grey = context.vColors.grayText;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Dish Info')),
              _TextAction(
                label: 'Add',
                icon: Icons.add_rounded,
                color: accent,
                onTap: () => _showAddDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
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
                  ? '$qtyStr g'
                  : '$qtyStr ${foodItem.unit} (~${weightStr}g)';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dish.name, style: context.text.titleSmall),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            '${dish.calories} kcal · $subtitleText',
                            style: context.text.bodySmall?.copyWith(color: grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    _RowIconButton(
                      asset: 'assets/icons/edit.svg',
                      tooltip: 'Edit',
                      onTap: () => _showEditDialog(context, dish),
                    ),
                    const SizedBox(width: AppDimens.space8),
                    _RowIconButton(
                      asset: 'assets/icons/delete.svg',
                      tooltip: 'Remove',
                      onTap: () => onRemove(dish.id),
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
    final hasMore = widget.details.length > 5;
    final visibleDetails = _isExpanded ? widget.details : widget.details.take(5).toList();

    final totalGrams = widget.macros.fold<double>(0, (sum, m) => sum + m.grams) +
        widget.details
            .where((d) => d.unit.toLowerCase() == 'g')
            .fold<double>(0, (sum, d) => sum + d.grams);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Macros')),
              if (hasMore)
                _TextAction(
                  label: _isExpanded ? 'Less Details' : 'More Details',
                  icon: _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _accentText(context),
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppDimens.cardInnerGap),
          for (var i = 0; i < widget.macros.length; i++) ...[
            _MacroMainRow(widget.macros[i]),
            if (i != widget.macros.length - 1)
              const SizedBox(height: AppDimens.space20),
          ],
          if (visibleDetails.isNotEmpty) ...[
            const SizedBox(height: AppDimens.cardInnerGap),
            const Divider(),
            const SizedBox(height: AppDimens.cardInnerGap),
            for (final detail in visibleDetails) ...[
              _MacroDetailRow(detail),
              const SizedBox(height: AppDimens.space8),
            ],
          ] else
            const SizedBox(height: AppDimens.cardInnerGap),
          const Divider(),
          const SizedBox(height: AppDimens.cardInnerGap),
          Text(
            'Total: ${totalGrams.round()}g of macronutrients',
            style: context.text.bodyMedium?.copyWith(
              color: context.vColors.grayText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(macro.name, style: context.text.headlineSmall),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${macro.grams}',
                    style: context.text.titleSmall,
                  ),
                  TextSpan(
                    text: ' g (${macro.percent}%)',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.vColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.space4),
        AppProgressBar(
          value: macro.percent / 100,
          color: macro.color,
          trackColor: macro.color.withValues(alpha: 0.12),
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
    final gramsStr = detail.grams == detail.grams.roundToDouble()
        ? detail.grams.round().toString()
        : detail.grams.toStringAsFixed(1);

    return Row(
      children: [
        Expanded(child: Text(detail.name, style: context.text.bodyMedium)),
        const SizedBox(width: AppDimens.space8),
        Text('$gramsStr ${detail.unit}', style: context.text.bodyMedium),
      ],
    );
  }
}

class _MealInfoPopup extends StatelessWidget {
  final MealPopupData data;

  const _MealInfoPopup({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: context.colors.primary,
                size: AppDimens.iconXl,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: context.text.headlineSmall),
                    Text(
                      data.time,
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          const Divider(),
          const SizedBox(height: AppDimens.space12),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: context.colors.primary,
                size: AppDimens.iconXl,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text('Suggestions', style: context.text.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          const Divider(),
          const SizedBox(height: AppDimens.space12),
          for (var i = 0; i < suggestions.length; i++) ...[
            _SuggestionRow(number: i + 1, text: suggestions[i]),
            if (i != suggestions.length - 1)
              const SizedBox(height: AppDimens.space12),
          ],
        ],
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
        const SizedBox(width: AppDimens.space12),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
        const SizedBox(width: AppDimens.space8),
        Icon(
          Icons.chevron_right_rounded,
          size: AppDimens.iconLg,
          color: context.vColors.grayText,
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
    final accent = _accentText(context);
    return Container(
      width: AppDimens.numberBadge,
      height: AppDimens.numberBadge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$number',
          style: context.text.bodySmall?.copyWith(color: accent),
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
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.space6),
            child: Container(
              width: AppDimens.bulletDot,
              height: AppDimens.bulletDot,
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Card eyebrow — Figma "caption 12" (JetBrains Mono), sentence case.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: context.vColors.grayText),
    );
  }
}

/// "Add +" / "More Details ⌄" link in a card header.
class _TextAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TextAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.titleSmall?.copyWith(color: color),
            ),
            const SizedBox(width: AppDimens.space8),
            Icon(icon, size: AppDimens.iconSm, color: color),
          ],
        ),
      ),
    );
  }
}

class _RowIconButton extends StatelessWidget {
  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  const _RowIconButton({
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space4),
          child: SvgPicture.asset(
            asset,
            width: AppDimens.iconLg,
            height: AppDimens.iconLg,
            colorFilter: ColorFilter.mode(
              context.colors.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 70) return AppColors.gradeGood;
  if (score >= 55) return AppColors.gradeModerate;
  return AppColors.gradeBad;
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
