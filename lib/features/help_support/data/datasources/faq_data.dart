import '../../domain/entities/faq_item.dart';

const List<FaqItem> kFaqDatabase = [
  // ── Getting Started ──
  FaqItem(
    id: 'gs_1',
    category: FaqCategory.gettingStarted,
    question: 'What is VitalUp and how does it help me?',
    answer:
        'VitalUp is an all-in-one health, fitness, and longevity companion. It unites high-precision GPS activity tracking, smart hydration monitoring with pace alerts, circular dial sleep scoring, intelligent AI food scanning, and screen time balance into a single cohesive offline-first experience.',
    tags: ['overview', 'vitalup', 'basics', 'introduction'],
  ),
  FaqItem(
    id: 'gs_2',
    category: FaqCategory.gettingStarted,
    question: 'How do I personalize my daily health goals?',
    answer:
        'You can update your target steps, active workout minutes, daily water intake, sleep duration, and calorie goals directly in the Activity Goals section or via the Settings page. VitalUp dynamically adapts recommendations based on your progress.',
    tags: ['goals', 'targets', 'steps', 'water', 'calories'],
    actionLabel: 'Open Goals',
    actionRoute: 'activity-goals',
  ),

  // ── Activity & Workouts ──
  FaqItem(
    id: 'act_1',
    category: FaqCategory.activity,
    question: 'How does live workout tracking and GPS work?',
    answer:
        'When you start an outdoor run, walk, or cycle, VitalUp uses Mapbox vector maps and high-precision GPS positioning. The app runs a foreground battery-optimized service that continues tracking even if your screen is off or you switch apps.',
    tags: ['gps', 'workouts', 'map', 'running', 'cycling', 'walking'],
    actionLabel: 'Track Workout',
    actionRoute: 'activity-tracking',
  ),
  FaqItem(
    id: 'act_2',
    category: FaqCategory.activity,
    question: 'Can I customize the metrics shown during my workout?',
    answer:
        'Yes. While tracking or in workout settings, tap "Customize Layout" to reorder and toggle metrics such as Current Pace, Heart Rate, Elevation, Split Times, and Calories.',
    tags: ['metrics', 'layout', 'customization', 'hud'],
    actionLabel: 'Customize HUD',
    actionRoute: 'activity-tracking',
  ),
  FaqItem(
    id: 'act_3',
    category: FaqCategory.activity,
    question: 'How do Voice Coach / Audio Announcements work?',
    answer:
        'VitalUp includes automated Text-to-Speech coaching that announces your split times, distance intervals (e.g. every 1 km), heart rate zones, and pace milestones through your headphones without needing to look at your phone.',
    tags: ['audio', 'voice coach', 'tts', 'split', 'headphones'],
    actionLabel: 'Audio Settings',
    actionRoute: 'activity-tracking',
  ),

  // ── Hydration ──
  FaqItem(
    id: 'hyd_1',
    category: FaqCategory.hydration,
    question: 'How do I log water intake quickly?',
    answer:
        'On the main Dashboard Water Card, you have 1-tap quick buttons for a 150ml Cup, 250ml Glass, and 500ml Bottle. You can also tap "+ Custom" to enter any exact amount or access historical logs.',
    tags: ['water', 'logging', 'intake', 'glass', 'bottle'],
    actionLabel: 'View Water Trends',
    actionRoute: 'water-trends',
  ),
  FaqItem(
    id: 'hyd_2',
    category: FaqCategory.hydration,
    question: 'What do the Hydration Pace indicators mean?',
    answer:
        'VitalUp calculates expected water intake throughout your waking day (e.g., 200ml every 2 hours). "On Track" means you are well hydrated, "Hydration Nudge" indicates you are falling behind your optimal pace, and "Goal Met" celebrates reaching 100% of your daily target.',
    tags: ['pace', 'hydration nudge', 'status', 'goal'],
  ),

  // ── Sleep & Recovery ──
  FaqItem(
    id: 'slp_1',
    category: FaqCategory.sleep,
    question: 'How is the Sleep Score calculated?',
    answer:
        'The Sleep Score (0–100%) evaluates three pillars: (1) Total Duration vs your target (e.g., 7–9 hrs), (2) Sleep Architecture (Deep & REM stage balance if synced from a smartwatch), and (3) Consistency (regularity of bedtime and wake-up schedule).',
    tags: ['sleep score', 'duration', 'deep sleep', 'rem', 'consistency'],
    actionLabel: 'Sleep Trends',
    actionRoute: 'sleep-trends',
  ),
  FaqItem(
    id: 'slp_2',
    category: FaqCategory.sleep,
    question: 'How do I use the 24-Hour Circular Dial to log sleep?',
    answer:
        'Tap the Moon/Sun icon on the Sleep Card to open the circular dial clock. Drag the Moon handle to set your bedtime and the Sun handle to set your wake time. The dial updates your duration and projected score in real time with haptic ticks.',
    tags: ['dial', 'clock', 'bedtime', 'wake', 'interactive'],
  ),

  // ── Nutrition & Food Scanner ──
  FaqItem(
    id: 'nut_1',
    category: FaqCategory.nutrition,
    question: 'How does the AI Food & Nutrition Scanner work?',
    answer:
        'Open the Food Scanner and aim your camera at a meal or a packaged food item. Google ML Kit processes barcodes or extracts nutritional text from labels (Calories, Protein, Carbs, Fats, Fiber) in sub-second offline processing.',
    tags: ['food scanner', 'camera', 'barcode', 'ocr', 'macros'],
    actionLabel: 'Open Scanner',
    actionRoute: 'food-scan',
  ),
  FaqItem(
    id: 'nut_2',
    category: FaqCategory.nutrition,
    question: 'Can Vita AI generate a personalized diet plan?',
    answer:
        'Yes. Vita AI analyzes your metabolic rate, dietary preferences (vegetarian, vegan, keto, high-protein), allergies, and fitness goal (fat loss, maintenance, muscle gain) to generate tailored daily recipes and macro breakdowns.',
    tags: ['diet plan', 'vita', 'ai', 'recipes', 'macros'],
    actionLabel: 'Diet Plan',
    actionRoute: 'vita-diet-plan',
  ),

  // ── Screen Time ──
  FaqItem(
    id: 'scr_1',
    category: FaqCategory.screenTime,
    question: 'Why does Screen Time require Usage Access permission?',
    answer:
        'Android protects your app usage privacy. Granting "Usage Access" allows VitalUp to read total screen-on time and categorize device activity so you can balance digital wellness and reduce late-night screen time before bed.',
    tags: ['screen time', 'permission', 'usage access', 'digital wellness'],
    actionLabel: 'Screen Time Trends',
    actionRoute: 'screen-time-trends',
  ),

  // ── Health Sync & Hardware ──
  FaqItem(
    id: 'snc_1',
    category: FaqCategory.sync,
    question: 'How do I connect Health Connect or Apple Health?',
    answer:
        'Go to Settings → Alerts & Integrations → Health Sync. Toggle it on and grant read permissions for Workouts, Steps, Weight, and Sleep Stages. VitalUp will seamlessly import background data from Garmin, Fitbit, Galaxy Watch, Apple Watch, and Pixel Watch.',
    tags: ['health connect', 'apple health', 'smartwatch', 'garmin', 'fitbit'],
    actionLabel: 'Open Settings',
    actionRoute: 'settings',
  ),

  // ── Account & Privacy ──
  FaqItem(
    id: 'acc_1',
    category: FaqCategory.account,
    question: 'Is my health data stored privately and offline?',
    answer:
        'Yes. VitalUp uses local high-speed encrypted Isar databases on your device for immediate offline access. When connected to the internet, data safely synchronizes with your personal Supabase cloud profile with end-to-end Row-Level Security (RLS).',
    tags: ['privacy', 'offline', 'encryption', 'supabase', 'security'],
  ),
  FaqItem(
    id: 'acc_2',
    category: FaqCategory.account,
    question: 'How do I delete my account or export data?',
    answer:
        'You can permanently delete your account and all associated cloud/local records anytime by navigating to Settings → Account → Delete Account. All data is purged immediately.',
    tags: ['delete account', 'data export', 'gdpr', 'privacy'],
    actionLabel: 'Account Settings',
    actionRoute: 'settings',
  ),
];
