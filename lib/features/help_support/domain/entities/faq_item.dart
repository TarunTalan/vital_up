enum FaqCategory {
  all(label: 'All', icon: '✨'),
  gettingStarted(label: 'Getting Started', icon: '🚀'),
  activity(label: 'Activity & Workouts', icon: '🏃'),
  hydration(label: 'Hydration', icon: '💧'),
  nutrition(label: 'Diet & Nutrition', icon: '🥗'),
  sleep(label: 'Sleep & Recovery', icon: '🌙'),
  screenTime(label: 'Screen Time', icon: '📱'),
  sync(label: 'Health Sync', icon: '🔗'),
  account(label: 'Account & Privacy', icon: '🔒');

  final String label;
  final String icon;
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
