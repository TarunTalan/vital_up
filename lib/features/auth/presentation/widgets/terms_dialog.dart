import 'package:flutter/material.dart';

class TermsAndConditionsDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onAccept;

  const TermsAndConditionsDialog({
    super.key,
    required this.onDismiss,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Terms & Conditions',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '1. VitalUp is designed to support general health, wellness, and activity tracking, not medical care.\n\n'
                '2. The app does not replace professional medical advice, diagnosis, or treatment.\n\n'
                '3. Always consult a qualified healthcare provider before making health or fitness decisions.\n\n'
                '4. You must be legally eligible to use VitalUp and provide accurate, current information.\n\n'
                '5. You are responsible for safeguarding your account and all activity under it.\n\n'
                '6. Health data you enter is used to personalize insights and improve your experience.\n\n'
                '7. VitalUp is not liable for any loss or damages arising from use of the app.\n\n'
                '8. You retain ownership of your data while granting VitalUp permission to process it.\n\n'
                '9. Data is handled in accordance with our Privacy Policy and applicable laws.\n\n'
                '10. VitalUp may update features or suspend access for misuse or policy violations.\n\n'
                '11. The app is provided "as is" without guarantees of accuracy or availability.\n\n'
                '12. Data is handled in accordance with our Privacy Policy and applicable laws.\n\n'
                '13. VitalUp provides wellness insights based on user-submitted data and does not guarantee accuracy or outcomes.\n\n'
                '14. The app\'s features may evolve, be modified, or discontinued without prior notice.\n\n'
                '15. Users may not copy, distribute, or exploit any part of the app without written consent.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onAccept,
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
