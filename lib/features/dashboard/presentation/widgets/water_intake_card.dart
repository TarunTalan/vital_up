import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/water_wave_animation.dart';
import '../cubit/water_intake_cubit.dart';
import '../cubit/water_intake_state.dart';

class WaterIntakeCard extends StatefulWidget {
  const WaterIntakeCard({super.key});

  @override
  State<WaterIntakeCard> createState() => _WaterIntakeCardState();
}

class _WaterIntakeCardState extends State<WaterIntakeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return BlocConsumer<WaterIntakeCubit, WaterIntakeState>(
      listenWhen: (previous, current) {
        // If current logs size is greater than previous, a new log was added
        if (previous is WaterIntakeLoaded && current is WaterIntakeLoaded) {
          return current.todayLogs.length > previous.todayLogs.length;
        }
        return false;
      },
      listener: (context, state) {
        if (state is WaterIntakeLoaded && state.todayLogs.isNotEmpty) {
          final addedAmount = state.todayLogs.last.amountMl;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Added $addedAmount ml of water'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    context.read<WaterIntakeCubit>().undoLast();
                  },
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        if (state is WaterIntakeLoaded) {
          final percentage = state.dailyGoalMl > 0 
              ? (state.currentIntakeMl / state.dailyGoalMl) 
              : 0.0;
          
          return _buildCard(context, theme, state, percentage);
        }
        
        return Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, 
    ThemeData theme, 
    WaterIntakeLoaded state, 
    double percentage,
  ) {
    final colors = theme.colorScheme;
    final int percentageInt = (percentage * 100).clamp(0, 100).toInt();
    
    return Semantics(
      label: '$percentageInt% of daily water goal, ${state.currentIntakeMl} of ${state.dailyGoalMl} milliliters',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Section (Text & Goal Edit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water Intake',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF161616),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${state.currentIntakeMl}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            ' / ${state.dailyGoalMl} ml',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF777777),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20, color: Color(0xFF777777)),
                    onPressed: () => _showEditGoalSheet(context, state.dailyGoalMl),
                    tooltip: 'Edit Daily Goal',
                  ),
                ],
              ),
            ),
            
            // Middle Section (Water Bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 120,
                child: WaterWaveAnimation(
                  fillPercentage: percentage,
                  waveColor: const Color(0xFF42A5F5),
                  backgroundColor: const Color(0xFFE3F2FD).withValues(alpha: 0.5),
                ),
              ),
            ),
            
            // Bottom Section (Quick Add Buttons)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _QuickAddButton(
                            amountMl: 150,
                            label: '150ml',
                            icon: Icons.local_drink_outlined,
                          ),
                          _QuickAddButton(
                            amountMl: 250,
                            label: '250ml',
                            icon: Icons.local_cafe_outlined,
                          ),
                          _QuickAddButton(
                            amountMl: 500,
                            label: '500ml',
                            icon: Icons.water_drop_outlined,
                          ),
                          _QuickAddButton(
                            amountMl: null,
                            label: 'Custom',
                            icon: Icons.add,
                            onTapCustom: () => _showCustomAddSheet(context),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(height: 16, width: double.infinity),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showEditGoalSheet(BuildContext context, int currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());
    _showNumberInputSheet(
      context: context,
      title: 'Daily Water Goal (ml)',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val != null && val > 0) {
          context.read<WaterIntakeCubit>().updateGoal(val);
        }
      },
    );
  }

  void _showCustomAddSheet(BuildContext context) {
    final controller = TextEditingController();
    _showNumberInputSheet(
      context: context,
      title: 'Add Water (ml)',
      controller: controller,
      onSave: () {
        final val = int.tryParse(controller.text);
        if (val != null && val > 0) {
          context.read<WaterIntakeCubit>().addWater(val);
        }
      },
    );
  }

  void _showNumberInputSheet({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    onSave();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int? amountMl;
  final String label;
  final IconData icon;
  final VoidCallback? onTapCustom;

  const _QuickAddButton({
    required this.amountMl,
    required this.label,
    required this.icon,
    this.onTapCustom,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () {
        if (amountMl != null) {
          context.read<WaterIntakeCubit>().addWater(amountMl!);
        } else if (onTapCustom != null) {
          onTapCustom!();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        label: 'Add $label of water',
        button: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: const Color(0xFF1976D2)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
