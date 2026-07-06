import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/food_scanner/data/models/food_scanner_models.dart';

class FoodDetailPage extends StatelessWidget {
  final String? imagePath;

  const FoodDetailPage({
    super.key,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _FoodScannerStyle.onBackground,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                _FoodScannerStyle.paddingLarge,
                _FoodScannerStyle.paddingSmall,
                _FoodScannerStyle.paddingLarge,
                _FoodScannerStyle.paddingLarge,
              ),
              children: [
                _ScannedDish(imagePath: imagePath),
                const SizedBox(height: _FoodScannerStyle.rowSpacing),
                const _KeyMatrices(),
                const SizedBox(height: _FoodScannerStyle.rowSpacing),
                const _DishInfoCard(),
                const SizedBox(height: _FoodScannerStyle.rowSpacing),
                const _MacroCard(),
                const SizedBox(height: _FoodScannerStyle.rowSpacing),
                const _MealInfoPopup(),
                const SizedBox(height: _FoodScannerStyle.rowSpacing),
                const _Suggestions(),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  static const double iconSize = 18;
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

  const _ScannedDish({this.imagePath});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (imagePath != null)
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
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 64,
                    color: colors.primary,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_rounded),
                      color: _FoodScannerStyle.onBackground,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded),
                      color: _FoodScannerStyle.onBackground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyMatrices extends StatelessWidget {
  const _KeyMatrices();

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
            'Dish Name',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: _FoodScannerStyle.textMedium,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _CircularScoreMeter(score: 70),
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
                        children: const [
                          TextSpan(text: '348'),
                          TextSpan(
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
          Text(
            '$clamped $label',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: _FoodScannerStyle.textMedium,
                ),
          ),
        ],
      ),
    );
  }
}

class _DishInfoCard extends StatelessWidget {
  const _DishInfoCard();

  static const dishes = [
    DishItem(name: 'Chopped Onions', calories: 5),
    DishItem(name: 'Cucumber Slices', calories: 8),
    DishItem(name: 'Pav', calories: 328),
    DishItem(name: 'Pav Bhaji', calories: 716),
    DishItem(name: 'Lime Wedge', calories: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Dish Info')),
              InkWell(
                onTap: () {},
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
          for (final dish in dishes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dish.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: _FoodScannerStyle.textMedium,
                      ),
                    ),
                  ),
                  Text(
                    '${dish.calories} kcal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: _FoodScannerStyle.textSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {},
                    child: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {},
                    child: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard();

  static const macros = [
    MacroMain(
      name: 'Protein',
      grams: 38,
      percent: 43,
      color: Color(0xFF00B3A4),
    ),
    MacroMain(
      name: 'Carbs',
      grams: 38,
      percent: 43,
      color: Color(0xFFFFB300),
    ),
    MacroMain(
      name: 'Fat',
      grams: 38,
      percent: 43,
      color: Color(0xFF9C7CFF),
    ),
  ];

  static const details = [
    MacroDetail(name: 'Dietary Fiber', grams: 5),
    MacroDetail(name: 'Total Sugars', grams: 8),
    MacroDetail(name: 'Saturated Fat', grams: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('Macros')),
              InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text(
                      'Less Details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _FoodScannerStyle.action,
                        fontSize: _FoodScannerStyle.textSmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: _FoodScannerStyle.action,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final macro in macros) ...[
            _MacroMainRow(macro),
            const SizedBox(height: 14),
          ],
          const Divider(height: 32, color: _FoodScannerStyle.divider),
          for (final detail in details) ...[
            _MacroDetailRow(detail),
            const SizedBox(height: 10),
          ],
          const Divider(height: 32, color: _FoodScannerStyle.divider),
          Text(
            'Total: 88g of macronutrients',
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
          value: macro.percent / 100,
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
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85);

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
          '${detail.grams} g',
          style: TextStyle(
            color: color,
            fontSize: _FoodScannerStyle.textMedium,
          ),
        ),
      ],
    );
  }
}

class _MealInfoPopup extends StatelessWidget {
  const _MealInfoPopup();

  static const data = MealPopupData(
    title: 'Lunch',
    time: '12:45 PM',
    points: [
      'Great timing! This meal fits well in your afternoon eating window.',
      'Eating protein-rich meals during midday helps maintain energy levels and supports muscle protein synthesis.',
    ],
  );

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
              Icon(
                Icons.schedule_rounded,
                color: colors.primary,
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
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.close_rounded,
                  color: _FoodScannerStyle.subtleText,
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
  const _Suggestions();

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
              Icon(
                Icons.lightbulb_outline_rounded,
                color: colors.primary,
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
          const _SuggestionRow(
            number: 1,
            text:
                'Consider adding colourful veggies like bell peppers or cherry tomatoes for extra vitamins.',
          ),
          const SizedBox(height: 8),
          const _SuggestionRow(
            number: 2,
            text:
                'Try a lighter dressing or use it on the side to reduce added sugars.',
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final int number;
  final String text;

  const _SuggestionRow({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NumberIcon(number),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.2,
                ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 16),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.2,
                  ),
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
