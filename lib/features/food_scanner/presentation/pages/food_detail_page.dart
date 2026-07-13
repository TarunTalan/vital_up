import 'package:flutter/material.dart';

class FoodDetailPage extends StatelessWidget {
  final String? imagePath;

  const FoodDetailPage({super.key, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Food Detail Coming Soon'),
      ),
    );
  }
}
