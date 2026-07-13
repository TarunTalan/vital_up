import 'package:flutter/material.dart';

class FoodScannerPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigateToDetail;

  const FoodScannerPage({
    super.key,
    required this.onBack,
    required this.onNavigateToDetail,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Food Scanner Coming Soon'),
      ),
    );
  }
}
