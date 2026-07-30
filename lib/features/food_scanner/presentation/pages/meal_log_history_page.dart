import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';

class MealLogHistoryPage extends StatelessWidget {
  const MealLogHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
      child: const _MealLogHistoryView(),
    );
  }
}

class _MealLogHistoryView extends StatelessWidget {
  const _MealLogHistoryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Today's Meals",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocBuilder<MealLogBloc, MealLogState>(
        builder: (context, state) {
          if (state is MealLogLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MealLogError) {
            return Center(
              child: Text(
                'Failed to load meals: ${state.message}',
                style: TextStyle(color: colors.error),
              ),
            );
          }

          if (state is MealLogLoaded) {
            if (state.entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 64,
                      color: colors.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No meals logged today.',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: state.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = state.entries[index];
                return _MealLogTile(entry: entry);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _MealLogTile extends StatelessWidget {
  final MealLogEntry entry;

  const _MealLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MealTypeBadge(mealType: entry.mealType),
              const Spacer(),
              Text(
                timeFormat.format(entry.capturedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.read<MealLogBloc>().add(DeleteMealLogEntry(entry.id));
                },
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.items.map((i) => i.name).join(', '),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroPill(
                label: 'Cals',
                value: '${entry.totalCalories.toInt()}',
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              if (entry.nutrition.isNotEmpty) ...[
                _MacroPill(
                  label: 'P',
                  value: '${entry.nutrition.first.proteinG.toInt()}g',
                  color: const Color(0xFF5B8DEF),
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'C',
                  value: '${entry.nutrition.first.carbsG.toInt()}g',
                  color: const Color(0xFF6DC16D),
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'F',
                  value: '${entry.nutrition.first.fatG.toInt()}g',
                  color: const Color(0xFFEF8C5B),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MealTypeBadge extends StatelessWidget {
  final MealType mealType;

  const _MealTypeBadge({required this.mealType});

  String get _label {
    switch (mealType) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
      case MealType.snack:     return 'Snack';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
