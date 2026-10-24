import 'package:flutter/material.dart';

enum FaqCategory {
  all(label: 'All', icon: Icons.apps_rounded),
  gettingStarted(label: 'Getting started', icon: Icons.rocket_launch_rounded),
  activity(label: 'Activity & workouts', icon: Icons.directions_run_rounded),
  hydration(label: 'Hydration', icon: Icons.water_drop_rounded),
  nutrition(label: 'Diet & nutrition', icon: Icons.restaurant_rounded),
  sleep(label: 'Sleep', icon: Icons.bedtime_rounded),
  screenTime(label: 'Screen time', icon: Icons.smartphone_rounded),
  sync(label: 'Health sync & backup', icon: Icons.sync_rounded),
  arena(label: 'Arena', icon: Icons.emoji_events_rounded),
  app(label: 'Settings & Pro', icon: Icons.tune_rounded),
  account(label: 'Account & privacy', icon: Icons.lock_rounded);

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
