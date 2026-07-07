import 'package:flutter/material.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_recommendation.dart';

class MealRecommendationWidget extends StatelessWidget {
  final MealRecommendation recommendation;

  const MealRecommendationWidget({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.green[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommendation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation.message,
              style: TextStyle(
                color: Colors.green[900],
                fontSize: 14,
              ),
            ),
            if (recommendation.reasonTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recommendation.reasonTags
                    .map((tag) => Chip(
                          label: Text(
                            _formatTag(tag),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.green[100],
                          labelStyle: TextStyle(color: Colors.green[900]),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTag(String tag) {
    return tag
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
