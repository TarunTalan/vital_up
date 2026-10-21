import '../../domain/entities/faq_item.dart';

/// Help articles. Keep every answer true to the app (paths, labels, limits)
/// and every `actionRoute` a route that opens without `extra`
/// (`test/features/help_support/faq_data_test.dart` checks the routes).
const List<FaqItem> kFaqDatabase = [
  // Getting started
  FaqItem(
    id: 'gs_1',
    category: FaqCategory.gettingStarted,
    question: 'What is VitalUp?',
    answer:
        'VitalUp tracks your food, water, sleep, activity, weight, mood and '
        'screen time in one place. Vita, the AI coach, gives tips from what '
        'you log, and Arena adds points, streaks and challenges. Your logs '
        'are saved on your phone and backed up to your account.',
    tags: ['overview', 'about', 'basics', 'start', 'new'],
  ),
  FaqItem(
    id: 'gs_2',
    category: FaqCategory.gettingStarted,
    question: 'How do I change my goals?',
    answer:
        'Profile > My goals gathers every goal in one place: your plan, '
        'weight, '
        'activity, water, sleep and screen time. Tap one to change it.',
    tags: ['goal', 'target', 'steps', 'calories', 'water goal', 'sleep goal'],
    actionLabel: 'My goals',
    actionRoute: 'my-goals',
  ),
  FaqItem(
    id: 'gs_3',
    category: FaqCategory.gettingStarted,
    question: 'What can Vita do, and what does it see?',
    answer:
        'Vita is the AI coach in the Vita tab. Ask it about food, sleep, '
        'stress, activity or how to use the app.\n'
        '• Vita sees nothing until you agree, and Health Connect readings '
        'only if you allow them.\n'
        '• Change this any time in Settings > Privacy & security > AI coach '
        'data.\n'
        '• Free accounts get 15 chats a day, Pro 150.',
    tags: ['vita', 'ai', 'coach', 'chat', 'assistant', 'insights', 'limit'],
    actionLabel: 'AI coach data',
    actionRoute: 'ai-coach-data',
  ),

  // Activity & workouts
  FaqItem(
    id: 'act_1',
    category: FaqCategory.activity,
    question: 'How do I track a workout?',
    answer:
        'Tap Start activity on Home.\n'
        '• Walk, run and cycle record your route with GPS. Keep the app open '
        'or in the background: the notification shows it is recording.\n'
        '• Yoga, strength and other workouts use a timer.\n'
        '• If the app is closed mid-workout, open it again to resume or '
        'save.',
    tags: ['workout', 'gps', 'map', 'run', 'walk', 'cycle', 'timer', 'yoga'],
    actionLabel: 'Start activity',
    actionRoute: 'activity-tracking',
  ),
  FaqItem(
    id: 'act_2',
    category: FaqCategory.activity,
    question: 'Can I change what shows during a workout?',
    answer:
        'Tap the settings button on the workout screen. There you can set a '
        'target, turn the voice coach on (it speaks every km or mile), pair '
        'a heart rate strap and choose which stats show.',
    tags: [
      'settings',
      'layout',
      'metrics',
      'voice coach',
      'heart rate',
      'target',
    ],
    actionLabel: 'Start activity',
    actionRoute: 'activity-tracking',
  ),
  FaqItem(
    id: 'act_3',
    category: FaqCategory.activity,
    question: 'I forgot to record a workout. Can I add it?',
    answer:
        'Yes. Open activity history and tap + to log a past workout from '
        'the last 30 days. It counts toward your goals, challenges and '
        'badges like a recorded one.',
    tags: ['past workout', 'forgot', 'add', 'manual', 'history'],
    actionLabel: 'Activity history',
    actionRoute: 'activity-history',
  ),
  FaqItem(
    id: 'act_4',
    category: FaqCategory.activity,
    question: 'Does tracking work without internet?',
    answer:
        'Yes. GPS, the timer and saving workouts never need a connection; '
        'they back up once you are online. The map needs a saved copy:\n'
        '• The map around you is saved automatically, over Wi-Fi or mobile '
        'data.\n'
        '• For trips and trails, go to the workout screen > settings > '
        'Offline maps > Download a new area before you go.',
    tags: ['offline', 'no signal', 'no internet', 'map', 'download', 'trail'],
    actionLabel: 'Offline maps',
    actionRoute: 'offline-maps',
  ),

  // Hydration
  FaqItem(
    id: 'hyd_1',
    category: FaqCategory.hydration,
    question: 'How do I log water?',
    answer:
        'Tap Log water on the Water card and pick Cup (150 ml), Glass '
        '(250 ml), Bottle (500 ml), Large (750 ml) or type an amount.\n'
        '• Logged the wrong drink? Tap Undo on the message that follows.\n'
        '• You can also log from a water reminder or the Water home screen '
        'widget.\n'
        '• Change your daily goal on the water page.',
    tags: ['water', 'drink', 'hydration', 'ml', 'glass', 'bottle', 'undo'],
    actionLabel: 'Water history',
    actionRoute: 'water-trends',
  ),

  // Diet & nutrition
  FaqItem(
    id: 'nut_1',
    category: FaqCategory.nutrition,
    question: 'How does the food scanner work?',
    answer:
        'Open the Scan tab.\n'
        '• Point the camera at a barcode inside the frame to find a '
        'packaged food. This does not use a photo scan.\n'
        '• Or take a photo of your meal for an estimate of calories, '
        'protein, carbs and fat (5 photo scans a day free, more with Pro).\n'
        "• If a product isn't found, scan its nutrition label or add it "
        'yourself.\n'
        '• Check the amounts before saving: photo estimates can be off.',
    tags: ['food', 'scan', 'barcode', 'camera', 'photo', 'calories', 'meal'],
    actionLabel: 'Open the scanner',
    actionRoute: 'food-scan',
  ),
  FaqItem(
    id: 'nut_2',
    category: FaqCategory.nutrition,
    question: 'How do diet plans work?',
    answer:
        'Vita can make a day of meals from your goal, diet type and '
        'allergies, or you can set your own targets. Ask Vita in chat to '
        'swap a dish or change a meal.\n'
        '• Free accounts can make 3 AI plans a day, Pro 20.',
    tags: ['diet plan', 'meal plan', 'recipe', 'vegetarian', 'vegan'],
    actionLabel: 'Open diet plan',
    actionRoute: 'vita-diet-plan',
  ),

  // Sleep
  FaqItem(
    id: 'slp_1',
    category: FaqCategory.sleep,
    question: 'How do I log sleep?',
    answer:
        'On Home, tap Log sleep on the Sleep card. Drag the moon (bedtime) '
        'and the sun (wake-up) on the dial, or drag the arc to move the '
        'whole night.\n'
        "• Tap Going to bed at night and I'm up in the morning to time it "
        'for you.\n'
        '• VitalUp can estimate last night from when your screen was off. '
        'Review it to confirm or adjust.',
    tags: ['sleep', 'bedtime', 'wake', 'dial', 'estimate', 'night'],
    actionLabel: 'Sleep history',
    actionRoute: 'sleep-trends',
  ),
  FaqItem(
    id: 'slp_2',
    category: FaqCategory.sleep,
    question: 'How is the sleep score worked out?',
    answer:
        'The sleep score (0-100) mostly reflects how long you slept: 7 to 9 '
        'hours scores best. When your watch records sleep stages through '
        'Health Connect, deep and REM sleep count too.',
    tags: ['sleep score', 'score', 'deep', 'rem', 'stages'],
    actionLabel: 'Sleep history',
    actionRoute: 'sleep-trends',
  ),

  // Screen time
  FaqItem(
    id: 'scr_1',
    category: FaqCategory.screenTime,
    question: 'Why is my screen time empty?',
    answer:
        'Screen time needs Usage Access: allow VitalUp when the Screen time '
        'card asks, or in your phone settings under Usage access.\n'
        '• Set a daily limit on the screen time page.\n'
        '• Android keeps about 10 days of usage, so VitalUp saves each day '
        'to show your longer history.',
    tags: ['screen time', 'usage access', 'permission', 'phone', 'empty'],
    actionLabel: 'Screen time',
    actionRoute: 'screen-time-trends',
  ),

  // Health sync & backup
  FaqItem(
    id: 'snc_1',
    category: FaqCategory.sync,
    question: 'How do I connect my watch or Health Connect?',
    answer:
        '• Install Health Connect (Android) and open Settings > Connected > '
        'Health sync.\n'
        '• Turn it on and allow the data you want to share. VitalUp only '
        'reads it.\n'
        '• Weight, workouts and sleep come in when you open the app, at most '
        'once an hour.\n'
        "• If something is missing, open your watch's app first so it "
        'updates Health Connect.',
    tags: [
      'health connect',
      'apple health',
      'watch',
      'sync',
      'fitbit',
      'garmin',
      'samsung',
    ],
    actionLabel: 'Open settings',
    actionRoute: 'settings',
  ),
  FaqItem(
    id: 'snc_2',
    category: FaqCategory.sync,
    question: 'My data is missing or I have a new phone',
    answer:
        'Your logs are saved on your phone first, then backed up to your '
        'account when you are online.\n'
        '• On a new phone, sign in with the same account and stay online '
        'for a minute.\n'
        '• Pull down on Home to refresh.\n'
        '• Signing out uploads anything not yet backed up first.',
    tags: ['missing', 'lost', 'backup', 'restore', 'new phone', 'offline'],
  ),

  // Arena
  FaqItem(
    id: 'arn_1',
    category: FaqCategory.arena,
    question: 'How do points, levels and streaks work?',
    answer:
        'You earn points for logging and meeting goals each day. They build '
        'your level and streak.\n'
        '• Points are added once your day syncs, so go online now and then.\n'
        '• Rest days protect a streak: you earn one for every 7 active days, '
        'up to 2.\n'
        '• Badges, challenges, friends and leaderboards are in the Arena '
        'tab.',
    tags: ['points', 'streak', 'level', 'badge', 'rest day', 'arena'],
    actionLabel: 'View badges',
    actionRoute: 'badges',
  ),
  FaqItem(
    id: 'arn_2',
    category: FaqCategory.arena,
    question: 'Who can see me on leaderboards?',
    answer:
        'Choose who sees you, and whether your city shows, in Settings > '
        'Privacy & security > Leaderboards. Your health logs are never '
        'shown to others.',
    tags: ['leaderboard', 'friends', 'privacy', 'city', 'rank', 'hide'],
    actionLabel: 'Open settings',
    actionRoute: 'settings',
  ),

  // Settings & Pro
  FaqItem(
    id: 'app_1',
    category: FaqCategory.app,
    question: 'How do I set up reminders?',
    answer:
        'Turn reminders on or off and change their times in Profile > '
        'Reminders.\n'
        '• A reminder skips itself when you have already logged that habit '
        'today.\n'
        "• Not getting any? Check that notifications for VitalUp are on in "
        "your phone's settings.",
    tags: ['reminder', 'notification', 'alert', 'alarm', 'push'],
    actionLabel: 'Open reminders',
    actionRoute: 'reminders',
  ),
  FaqItem(
    id: 'app_2',
    category: FaqCategory.app,
    question: 'How do I add a home screen widget?',
    answer:
        "Touch and hold an empty spot on your phone's home screen, choose "
        'Widgets, then VitalUp. There are Today, My metrics, Water, Mood and '
        'Shortcuts widgets (Android).',
    tags: ['widget', 'home screen', 'shortcut'],
    actionLabel: 'See widgets',
    actionRoute: 'home-widgets',
  ),
  FaqItem(
    id: 'app_3',
    category: FaqCategory.app,
    question: 'What does VitalUp Pro add?',
    answer:
        'Pro raises the daily AI limits: photo scans, Vita chats and diet '
        'plans. Tracking, trends, reports, sync and Arena stay free.\n'
        '• Manage, cancel or ask for a refund in Google Play > Payments & '
        'subscriptions.\n'
        '• Bought Pro on another phone? Open VitalUp Pro and tap Restore '
        'purchases.',
    tags: ['pro', 'premium', 'subscription', 'cancel', 'refund', 'price'],
    actionLabel: 'VitalUp Pro',
    actionRoute: 'vitalup-pro',
  ),
  FaqItem(
    id: 'app_4',
    category: FaqCategory.app,
    question: 'How do I change the theme or units?',
    answer:
        '• Light, dark or match your phone: Settings > Appearance.\n'
        '• Weight, height and distance units: Settings > Units.',
    tags: ['theme', 'dark mode', 'units', 'kg', 'lbs', 'km', 'miles'],
    actionLabel: 'Open settings',
    actionRoute: 'settings',
  ),

  // Account & privacy
  FaqItem(
    id: 'acc_1',
    category: FaqCategory.account,
    question: 'Is my health data private?',
    answer:
        'Your logs are saved on your phone and backed up to your own '
        'account. Other people never see them. Vita uses them only after you '
        'agree, and you can turn off usage analytics in Settings > Privacy & '
        'security.',
    tags: ['privacy', 'data', 'security', 'analytics', 'offline'],
  ),
  FaqItem(
    id: 'acc_2',
    category: FaqCategory.account,
    question: 'How do I export or delete my data?',
    answer:
        'Open Profile > Account details.\n'
        '• Export my data saves a copy of everything you have logged.\n'
        '• Delete account removes your account and all its data. This '
        "can't be undone.",
    tags: ['delete account', 'export', 'download', 'remove', 'gdpr'],
  ),
  FaqItem(
    id: 'acc_3',
    category: FaqCategory.account,
    question: "I can't sign in",
    answer:
        '• You can sign in with your email or your username.\n'
        '• Forgot your password? Tap Forgot password on the sign-in screen '
        'and use the code we email you.\n'
        '• Signed up with Google? Sign in with Google again.',
    tags: ['sign in', 'login', 'password', 'username', 'google', 'code'],
  ),
];
