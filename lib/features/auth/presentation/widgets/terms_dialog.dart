import 'dart:ui';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = (screenWidth * 0.08).clamp(24.0, 36.0);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFE),
              borderRadius: BorderRadius.circular(20), // RoundedCornerShape(size = 20.dp)
              border: Border.all(
                color: const Color(0x45BABABA), // Color(0x45BABABA)
                width: 1.0, // 1.dp
              ),
            ),
            padding: const EdgeInsets.only(
              left: 20.0, // start = 20.dp
              top: 24.0, // top = 24.dp
              right: 20.0, // end = 20.dp
              bottom: 24.0, // bottom = 24.dp
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Terms & Conditions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize, // Matches auth screen size
                    fontFamily: 'SFProRounded',
                    fontWeight: FontWeight.w600, // FontWeight(600)
                    color: const Color(0xFF0C0C0C), // Color(0xFF0C0C0C)
                  ),
                ),
                const SizedBox(height: 20),
                
                // Scrollable terms list (bullets)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _TermItem(text: 'VitalApp is designed to support general health, wellness, and activity tracking, not medical care.'),
                        _TermItem(text: 'The app does not replace professional medical advice, diagnosis, or treatment.'),
                        _TermItem(text: 'Always consult a qualified healthcare provider before making health or fitness decisions.'),
                        _TermItem(text: 'You must be legally eligible to use VitalApp and provide accurate, current information.'),
                        _TermItem(text: 'You are responsible for safeguarding your account and all activity under it.'),
                        _TermItem(text: 'Health data you enter is used to personalize insights and improve your experience.'),
                        _TermItem(text: 'VitalApp is not liable for any loss or damages arising from use of the app.'),
                        _TermItem(text: 'You retain ownership of your data while granting VitalApp permission to process it.'),
                        _TermItem(text: 'Data is handled in accordance with our Privacy Policy and applicable laws.'),
                        _TermItem(text: 'VitalApp may update features or suspend access for misuse or policy violations.'),
                        _TermItem(text: 'The app is provided "as is" without guarantees of accuracy or availability.'),
                        _TermItem(text: 'Data is handled in accordance with our Privacy Policy and applicable laws.'),
                        _TermItem(text: 'VitalApp provides wellness insights based on user-submitted data and does not guarantee accuracy or outcomes.'),
                        _TermItem(text: 'The app\'s features may evolve, be modified, or discontinued without prior notice.'),
                        _TermItem(text: 'Users may not copy, distribute, or exploit any part of the app without written consent.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
  
                // Button: Back to login
                GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    width: 332, // width(332.dp)
                    height: 48, // height(48.dp)
                    decoration: BoxDecoration(
                      color: const Color(0xFF19C3E0), // Color(0xFF19C3E0)
                      borderRadius: BorderRadius.circular(14), // RoundedCornerShape(size = 14.dp)
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000), // spotColor 0x1A000000, 3.dp elevation
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Color(0x17000000), // spotColor 0x17000000, 6.dp elevation
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Color(0x0D000000), // spotColor 0x0D000000, 8.dp elevation
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Color(0x03000000), // spotColor 0x03000000, 9.dp elevation
                          blurRadius: 18,
                          offset: Offset(0, 9),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(
                      left: 16.0, // start = 16.dp
                      top: 12.0, // top = 12.dp
                      right: 16.0, // end = 16.dp
                      bottom: 12.0, // bottom = 12.dp
                    ),
                    child: const Text(
                      'Back to login',
                      style: TextStyle(
                        fontFamily: 'SFProRounded',
                        fontWeight: FontWeight.w500, // fontweight = 500
                        fontSize: 16,
                        color: Color(0xFF1C1C1C), // Text Color(0xFF1C1C1C)
                      ),
                    ),
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

class _TermItem extends StatelessWidget {
  final String text;

  const _TermItem({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 16,
            child: Text(
              '•',
              style: TextStyle(
                fontFamily: 'SFProRounded',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1C1C1C),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'SFProRounded',
                fontWeight: FontWeight.w400, // FontWeight(400)
                fontSize: 14, // 14.sp
                height: 1.4,
                color: Color(0xFF1C1C1C), // Color(0xFF1C1C1C)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
