import 'package:flutter/material.dart';

enum FaqCategory {
  all(label: 'All', icon: Icons.apps_rounded),
  gettingStarted(label: 'Getting Started', icon: Icons.rocket_launch_rounded),
  activity(label: 'Activity & Workouts', icon: Icons.directions_run_rounded),
  hydration(label: 'Hydration', icon: Icons.water_drop_rounded),
  nutrition(label: 'Diet & Nutrition', icon: Icons.restaurant_rounded),
  sleep(label: 'Sleep & Recovery', icon: Icons.bedtime_rounded),
  screenTime(label: 'Screen Time', icon: Icons.smartphone_rounded),
  sync(label: 'Health Sync', icon: Icons.sync_rounded),
  account(label: 'Account & Privacy', icon: Icons.lock_rounded);

  final String label;
  final IconData icon;
  const FaqCategory({required this.label, required this.icon});
}

class FaqItem {
  final String id;
  final FaqCategory category;
  final String question;
  final String answer;
  final List<String> tags;
  final String? actionLabel;
  final String? actionRoute;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.tags = const [],
    this.actionLabel,
    this.actionRoute,
  });
}
