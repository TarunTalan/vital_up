import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/di/injection_container.dart' as di;
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart' as vital_up_dashboard;
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize communication port for foreground task manager
  ForegroundServiceManager.init();

  // Set Mapbox access token globally (required by mapbox_maps_flutter v2.x)
  MapboxOptions.setAccessToken(SupabaseConfig.mapboxAccessToken);

  // Lock the app to Portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );

    // Initialize dependency injection (database, network, storage, etc.)
    await di.initDependencies();

    // Trigger background sync of popular products to offline DB
    final isarService = sl<IsarService>();
    final supabase = sl<SupabaseClient>();
    isarService.syncOfflineFoodsBackground(supabase);
  } catch (e, stackTrace) {
    debugPrint('INITIALIZATION ERROR: $e');
    debugPrint(stackTrace.toString());
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<AuthCubit>()..checkSession()),
        BlocProvider(create: (context) => sl<OnboardingCubit>()),
        BlocProvider(create: (context) => sl<vital_up_dashboard.ScreenTimeCubit>()..loadStats()),
        BlocProvider(create: (context) => sl<SleepCubit>()..loadSleepData()),
      ],
      child: MaterialApp.router(
        title: 'VitalUp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          return MultiBlocListener(
            listeners: [
              BlocListener<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state is AuthError) {
                    showErrorSnackBar(context, state.message);
                  }
                },
              ),
              BlocListener<OnboardingCubit, OnboardingData>(
                listenWhen: (previous, current) => previous.status != current.status,
                listener: (context, state) {
                  if (state.status == SubmissionStatus.error && state.errorMessage != null) {
                    showErrorSnackBar(context, state.errorMessage!);
                  } else if (state.status == SubmissionStatus.success) {
                    showSuccessSnackBar(context, 'Health profile completed successfully!');
                  }
                },
              ),
            ],
            child: child ?? const SizedBox(),
          );
        },
      ),
    );
  }
}
