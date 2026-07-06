import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_up/features/food_scan/domain/entities/food_item.dart';
import 'package:vital_up/features/food_scan/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scan/domain/entities/nutrition_info.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_bloc.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_event.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_state.dart';
import 'dart:io';

class FoodScanPage extends StatelessWidget {
  const FoodScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FoodScanBloc(
        scanFoodImage: context.read(),
        scanBarcode: context.read(),
        saveMealLog: context.read(),
        getMealRecommendation: context.read(),
        uuid: context.read(),
      ),
      child: const FoodScanView(),
    );
  }
}

class FoodScanView extends StatelessWidget {
  const FoodScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scan'),
        centerTitle: true,
      ),
      body: BlocListener<FoodScanBloc, FoodScanState>(
        listener: (context, state) {
          if (state is RecognitionSucceeded || state is RecognitionLowConfidence) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FoodScanResultPage(),
              ),
            );
          } else if (state is MealLogSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Meal saved successfully!')),
            );
            Navigator.of(context).pop();
          }
        },
        child: BlocBuilder<FoodScanBloc, FoodScanState>(
          builder: (context, state) {
            if (state is RecognizingFood) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Recognizing food...'),
                  ],
                ),
              );
            }

            if (state is RecognitionFailed) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.failure.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          context.read<FoodScanBloc>().add(
                            state.image != null
                                ? ImageSelected(state.image!)
                                : CaptureImageRequested(),
                          );
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _buildContent(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FoodScanState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              'Scan Your Food',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Capture or upload a photo of your meal to get nutrition information and track your calories.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildImageQualityTip(context),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickImage(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _pickImage(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _scanBarcode(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageQualityTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Tip for best results:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Use good lighting\n• Include the full plate in frame\n• Avoid steam or glare on food\n• Focus clearly on the food',
            style: TextStyle(
              color: Colors.blue[900],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final image = File(pickedFile.path);
      if (context.mounted) {
        context.read<FoodScanBloc>().add(ImageSelected(image));
        context.read<FoodScanBloc>().add(RecognizeFoodRequested());
      }
    }
  }

  Future<void> _scanBarcode(BuildContext context) async {
    // This would integrate with a barcode scanner
    // For now, we'll show a dialog to enter barcode manually
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter barcode number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Scan'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      context.read<FoodScanBloc>().add(ScanBarcodeRequested(result));
    }
  }
}

class FoodScanResultPage extends StatefulWidget {
  const FoodScanResultPage({super.key});

  @override
  State<FoodScanResultPage> createState() => _FoodScanResultPageState();
}

class _FoodScanResultPageState extends State<FoodScanResultPage> {
  MealType _selectedMealType = MealType.lunch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FoodScanBloc, FoodScanState>(
      builder: (context, state) {
        final image = state is RecognitionSucceeded
            ? state.image
            : state is RecognitionLowConfidence
                ? state.image
                : null;
        final items = state is RecognitionSucceeded
            ? state.items
            : state is RecognitionLowConfidence
                ? state.items
                : <FoodItem>[];
        final nutrition = state is RecognitionSucceeded
            ? state.nutrition
            : state is RecognitionLowConfidence
                ? state.nutrition
                : <NutritionInfo>[];
        final isLowConfidence = state is RecognitionLowConfidence;

        if (image == null || items.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No data available')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan Results'),
            centerTitle: true,
            actions: [
              if (isLowConfidence)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Chip(
                      label: const Text('Low Confidence'),
                      backgroundColor: Colors.orange[100],
                      labelStyle: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImagePreview(image),
                const SizedBox(height: 16),
                _buildNutritionSummary(nutrition),
                const SizedBox(height: 24),
                _buildFoodItemsList(context, items, nutrition),
                const SizedBox(height: 24),
                _buildMealTypeSelector(context),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _confirmAndSave(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm & Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(File image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        image,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNutritionSummary(List<NutritionInfo> nutrition) {
    final totalCalories = nutrition.fold<double>(0, (sum, nut) => sum + nut.calories);
    final totalProtein = nutrition.fold<double>(0, (sum, nut) => sum + nut.proteinG);
    final totalCarbs = nutrition.fold<double>(0, (sum, nut) => sum + nut.carbsG);
    final totalFat = nutrition.fold<double>(0, (sum, nut) => sum + nut.fatG);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Summary',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientItem('Calories', '${totalCalories.toStringAsFixed(0)} kcal', Colors.orange),
                _buildNutrientItem('Protein', '${totalProtein.toStringAsFixed(1)}g', Colors.red),
                _buildNutrientItem('Carbs', '${totalCarbs.toStringAsFixed(1)}g', Colors.blue),
                _buildNutrientItem('Fat', '${totalFat.toStringAsFixed(1)}g', Colors.yellow),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.circle, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFoodItemsList(BuildContext context, List<FoodItem> items, List<NutritionInfo> nutrition) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detected Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final nut = nutrition[index];
          return _buildFoodItemCard(context, item, nut, index);
        }),
      ],
    );
  }

  Widget _buildFoodItemCard(BuildContext context, FoodItem item, NutritionInfo nut, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (item.confidenceScore < 0.7)
                  Chip(
                    label: Text('${(item.confidenceScore * 100).toStringAsFixed(0)}%'),
                    backgroundColor: Colors.orange[100],
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    context.read<FoodScanBloc>().add(
                      RemoveDetectedItemRequested(item.id),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${item.servingDescription} • ${nut.calories.toStringAsFixed(0)} kcal'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantity: '),
                Expanded(
                  child: Slider(
                    value: item.quantity,
                    min: 0.5,
                    max: 3.0,
                    divisions: 5,
                    label: '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                    onChanged: (value) {
                      context.read<FoodScanBloc>().add(
                        AdjustPortionRequested(item.id, value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meal Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<MealType>(
          segments: const [
            ButtonSegment(
              value: MealType.breakfast,
              label: Text('Breakfast'),
              icon: Icon(Icons.wb_sunny),
            ),
            ButtonSegment(
              value: MealType.lunch,
              label: Text('Lunch'),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: MealType.dinner,
              label: Text('Dinner'),
              icon: Icon(Icons.nights_stay),
            ),
            ButtonSegment(
              value: MealType.snack,
              label: Text('Snack'),
              icon: Icon(Icons.cookie),
            ),
          ],
          selected: {_selectedMealType},
          onSelectionChanged: (Set<MealType> selected) {
            setState(() {
              _selectedMealType = selected.first;
            });
          },
        ),
      ],
    );
  }

  void _confirmAndSave(BuildContext context) {
    context.read<FoodScanBloc>().add(
      ConfirmAndSaveRequested(_selectedMealType),
    );
  }
}
