import 'package:uuid/uuid.dart';

class SupportBotMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionLabel;
  final String? actionRoute;
  final List<String> quickReplies;

  SupportBotMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.actionLabel,
    this.actionRoute,
    this.quickReplies = const [],
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();
}

class SupportBotService {
  static const _uuid = Uuid();

  static List<SupportBotMessage> getInitialMessages() {
    return [
      SupportBotMessage(
        id: _uuid.v4(),
        isUser: false,
        text:
            'Hi, I am the **VitalUp Support Assistant**.\n\nI can help you troubleshoot sync issues, explain metrics, set up goals, or connect you with our engineering team.',
        quickReplies: const [
          'Troubleshoot Health Sync',
          'How is Sleep Score calculated?',
          'Water Logging & Hydration',
          'Contact Support Email',
        ],
      ),
    ];
  }

  static SupportBotMessage generateReply(String userQuery) {
    final query = userQuery.toLowerCase().trim();

    // 1. Health Sync / Smartwatch
    if (query.contains('sync') ||
        query.contains('watch') ||
        query.contains('health connect') ||
        query.contains('apple health') ||
        query.contains('garmin') ||
        query.contains('fitbit') ||
        query.contains('wear')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Health Connect & Smartwatch Sync:**\n\n'
            '1. Ensure you have the **Google Health Connect** app installed.\n'
            '2. Go to **Settings → Alerts & Integrations → Health Sync**.\n'
            '3. Turn on the toggle and grant permissions for Workouts, Sleep, and Weight.\n'
            '4. If data is delayed, open your watch companion app (e.g. Fitbit/Garmin/Samsung Health) to force a refresh.',
        actionLabel: 'Open Settings',
        actionRoute: 'settings',
        quickReplies: const [
          'Sleep Score calculation',
          'How to log water?',
          'Email Support',
        ],
      );
    }

    // 2. Sleep Tracking & Score
    if (query.contains('sleep') || query.contains('bedtime') || query.contains('wake') || query.contains('dial')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Sleep Tracking & Score Guide:**\n\n'
            '• **Sleep Score (0–100%)** combines your target duration (8h recommended), sleep stage depth (Deep/REM), and schedule regularity.\n'
            '• **Interactive 24h Dial**: Tap the Moon/Sun on your Sleep Card to effortlessly set bedtime and wake time by dragging the handles.\n'
            '• **Auto-sync**: If you wear a compatible smartwatch to bed, stages are synced automatically.',
        actionLabel: 'View Sleep Trends',
        actionRoute: 'sleep-trends',
        quickReplies: const [
          'Hydration & Water logs',
          'Screen Time features',
          'Email Support',
        ],
      );
    }

    // 3. Water Intake & Hydration
    if (query.contains('water') || query.contains('hydration') || query.contains('drink') || query.contains('ml')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Water Intake & Hydration Pace:**\n\n'
            '• **1-Tap Presets**: Tap 150ml (Cup), 250ml (Glass), or 500ml (Bottle) directly on the Dashboard.\n'
            '• **Pace Status**:\n'
            '  - *On Track*: You are drinking regularly throughout the day.\n'
            '  - *Hydration Nudge*: Time for a glass of water.\n'
            '  - *Goal Met*: You hit 100% of your daily goal.',
        actionLabel: 'Water Trends & History',
        actionRoute: 'water-trends',
        quickReplies: const [
          'How to log sleep?',
          'Diet plan with Vita AI',
          'Email Support',
        ],
      );
    }

    // 4. Workout / GPS / Activity
    if (query.contains('workout') ||
        query.contains('run') ||
        query.contains('gps') ||
        query.contains('pace') ||
        query.contains('exercise') ||
        query.contains('step') ||
        query.contains('activity')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Workout Tracking & Voice Coach:**\n\n'
            '• **GPS Routing**: Uses Mapbox vector maps with high precision and low battery drain.\n'
            '• **Voice Coach**: Enable audio split announcements every 1 km so you don\'t need to glance at your screen.\n'
            '• **Custom HUD**: Tap "Customize Layout" during workouts to reorder pace, distance, and heart rate.',
        actionLabel: 'Open Workout Tracker',
        actionRoute: 'activity-tracking',
        quickReplies: const [
          'Customize HUD Layout',
          'Voice Coach Settings',
          'Email Support',
        ],
      );
    }

    // 5. Food Scanner / Nutrition / Diet Plan
    if (query.contains('food') ||
        query.contains('scan') ||
        query.contains('camera') ||
        query.contains('calorie') ||
        query.contains('diet') ||
        query.contains('meal') ||
        query.contains('recipe')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Food Scanner & AI Diet Plan:**\n\n'
            '• **Offline OCR Scanner**: Point your camera at food nutrition labels or barcodes for sub-second macro extraction.\n'
            '• **Vita Diet Planner**: AI plans customized recipes with exact calorie and protein targets tailored to your goals.',
        actionLabel: 'Open Food Scanner',
        actionRoute: 'food-scan',
        quickReplies: const [
          'Create Diet Plan',
          'Water Tracking',
          'Email Support',
        ],
      );
    }

    // 6. Screen Time & Digital Wellness
    if (query.contains('screen') || query.contains('usage') || query.contains('phone') || query.contains('app time')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Screen Time & Digital Wellness:**\n\n'
            '• Tracks total phone usage, daily averages, and highlights your lowest vs highest usage days.\n'
            '• Check the **7-Day Trend Graph** to identify screen time peaks before bedtime for better sleep hygiene.',
        actionLabel: 'Screen Time Trends',
        actionRoute: 'screen-time-trends',
        quickReplies: const [
          'Troubleshoot Health Sync',
          'Sleep Score guide',
          'Email Support',
        ],
      );
    }

    // 7. Account / Theme / Privacy
    if (query.contains('theme') ||
        query.contains('dark') ||
        query.contains('light') ||
        query.contains('delete') ||
        query.contains('account') ||
        query.contains('privacy') ||
        query.contains('offline')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Account & Customization:**\n\n'
            '• **Theme Toggle**: Switch between System, Light, and Dark mode in Settings.\n'
            '• **Offline Privacy**: Your metrics are stored locally in encrypted Isar databases and safely synced to your private Supabase profile.\n'
            '• **Account Deletion**: Navigate to Settings → Account → Delete Account.',
        actionLabel: 'Open Settings',
        actionRoute: 'settings',
        quickReplies: const [
          'Contact Support Email',
          'Troubleshoot Health Sync',
        ],
      );
    }

    // 8. Contact Support / Bug / Help
    if (query.contains('contact') ||
        query.contains('email') ||
        query.contains('bug') ||
        query.contains('error') ||
        query.contains('crash') ||
        query.contains('support') ||
        query.contains('human') ||
        query.contains('help')) {
      return SupportBotMessage(
        isUser: false,
        text:
            '**Direct Support & Bug Reporting:**\n\n'
            'Would you like to send an email ticket to our developer team?\n\n'
            'You can specify your issue category (Bug Report, Feature Request, Health Sync, etc.), write a description, and attach device diagnostics.',
        actionLabel: 'Submit Support Ticket',
        quickReplies: const [
          'Troubleshoot Health Sync',
          'Sleep Score guide',
          'Back to FAQs',
        ],
      );
    }

    // Default Fallback
    return SupportBotMessage(
      isUser: false,
      text:
          'I\'m here to help with all aspects of VitalUp.\n\n'
          'Could you clarify what you\'d like assistance with? You can choose one of the topics below or submit a ticket directly to our support team.',
      quickReplies: const [
        'Troubleshoot Health Sync',
        'How is Sleep Score calculated?',
        'Water Logging & Hydration',
        'Contact Support Email',
      ],
    );
  }
}
