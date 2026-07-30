import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';

class AccuracyInfoDialog extends StatelessWidget {
  const AccuracyInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF343434) : const Color(0xFFD8D8D8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'How accurate is this?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.biotech_outlined,
              'Dual AI Verification',
              'Recognized using dual vision engines (Google Gemini + Groq Qwen) to prevent identification errors.',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.menu_book_outlined,
              'Laboratory Mapped',
              'Calories and macros are pulled directly from USDA & Indian Food Composition Tables (IFCT) laboratory composition records—never guessed or hallucinated by AI.',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.travel_explore_outlined,
              'Google Search Grounding',
              'Recipes or regional dishes are double-checked using live web searches to map verified nutritional details.',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.warning_amber_rounded,
              'Low Confidence Alert',
              'If result confidence is under 70%, a caution alert is surfaced so you can inspect and modify portion sizes or items.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: theme.extension<VitalUpColors>()?.buttonText ?? const Color(0xFF0C0C0C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.primaryColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
                  height: 1.3,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
