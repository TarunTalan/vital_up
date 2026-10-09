import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/utils/date_range_utils.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Shown in the report for anything the user hasn't recorded. The report
/// goes to a doctor, so it never fills gaps with typical values.
const notRecorded = 'Not recorded';

/// A report figure, or [notRecorded] when there is none.
String reportValue(Object? value, String Function(Object v) format) =>
    value == null ? notRecorded : format(value);

/// Blood pressure from the profile, e.g. "120/80", or null unless both
/// numbers are plausible readings.
String? reportBloodPressure(String top, String bottom) {
  final sys = int.tryParse(top.trim());
  final dia = int.tryParse(bottom.trim());
  if (sys == null || dia == null) return null;
  if (sys < 50 || sys > 300 || dia < 30 || dia > 200 || dia >= sys) {
    return null;
  }
  return '$sys/$dia';
}

/// Resting heart rate from the profile, or null unless plausible.
int? reportRestingBpm(String bpm) {
  final value = int.tryParse(bpm.trim());
  return value != null && value >= 25 && value <= 250 ? value : null;
}

/// Average ml per day over the days that have any water logged, or null.
int? averageDailyWater(Map<DateTime, int> mlByDay) {
  final days = mlByDay.values.where((ml) => ml > 0).toList();
  if (days.isEmpty) return null;
  return (days.fold<int>(0, (s, ml) => s + ml) / days.length).round();
}

class HealthReportSummary {
  final int daysCount;
  final ProfileEntity? profile;

  /// Null when nothing was recorded in the period.
  final double? avgSleepHours;
  final int? avgSleepScore;
  final int nightsLogged;
  final int totalWorkouts;
  final int totalActiveMinutes;
  final double totalDistanceKm;
  final int? avgWaterMl;
  final int waterDaysLogged;
  final double? latestWeightKg;
  final String? bloodPressure;
  final int? restingBpm;

  const HealthReportSummary({
    required this.daysCount,
    this.profile,
    this.avgSleepHours,
    this.avgSleepScore,
    this.nightsLogged = 0,
    required this.totalWorkouts,
    required this.totalActiveMinutes,
    required this.totalDistanceKm,
    this.avgWaterMl,
    this.waterDaysLogged = 0,
    this.latestWeightKg,
    this.bloodPressure,
    this.restingBpm,
  });

  String toClinicalText({WeightUnit unit = WeightUnit.kg}) {
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final fullName = sanitizeText(
      profile?.fullName ?? '',
      maxLength: InputLimits.name,
    );
    final name = fullName.isNotEmpty ? fullName : 'Patient';
    String note(String? text) =>
        sanitizeText(text ?? '', maxLength: InputLimits.note);

    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('          VITALUP CLINICAL HEALTH REPORT            ');
    buffer.writeln('====================================================');
    buffer.writeln('Patient Name: $name');
    buffer.writeln('Report Date:  $dateStr');
    buffer.writeln('Time Horizon: Last $daysCount Days');
    buffer.writeln('Values are self-reported or from connected devices.');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('1. CARDIOVASCULAR & RESTING VITALS:');
    buffer.writeln(
      '   - Blood Pressure:    '
      '${reportValue(bloodPressure, (v) => '$v mmHg')}',
    );
    buffer.writeln(
      '   - Resting Heart Rate: ${reportValue(restingBpm, (v) => '$v BPM')}',
    );
    buffer.writeln(
      '   - Current Weight:    '
      '${reportValue(latestWeightKg, (v) => unit.format(v as double))}',
    );
    final conditions = note(profile?.healthConditions);
    if (conditions.isNotEmpty) {
      buffer.writeln('   - Medical Conditions: $conditions');
    }
    final allergies = note(profile?.allergies);
    if (allergies.isNotEmpty) buffer.writeln('   - Allergies:         $allergies');
    final medicines = note(profile?.medicines);
    if (medicines.isNotEmpty) buffer.writeln('   - Current Meds:      $medicines');
    buffer.writeln();
    buffer.writeln('2. SLEEP & RECOVERY ($nightsLogged nights recorded):');
    buffer.writeln(
      '   - Avg Daily Sleep:   '
      '${reportValue(avgSleepHours, (v) => '${(v as double).toStringAsFixed(1)} hrs/night')}',
    );
    buffer.writeln(
      '   - Avg Sleep Quality: ${reportValue(avgSleepScore, (v) => '$v / 100')}',
    );
    buffer.writeln();
    buffer.writeln('3. PHYSICAL ACTIVITY & CARDIO:');
    buffer.writeln('   - Total Workouts:    $totalWorkouts sessions');
    buffer.writeln('   - Active Minutes:    $totalActiveMinutes mins');
    buffer.writeln('   - Total Distance:    ${totalDistanceKm.toStringAsFixed(2)} km');
    buffer.writeln();
    buffer.writeln('4. HYDRATION ($waterDaysLogged days recorded):');
    buffer.writeln(
      '   - Avg Daily Intake:  ${reportValue(avgWaterMl, (v) => '$v ml / day')}',
    );
    buffer.writeln('====================================================');
    buffer.writeln('Generated by VitalUp from data on this device.');
    buffer.writeln('Confidential: for discussion with your doctor.');
    return buffer.toString();
  }
}

class HealthReportService {
  final ProfileRepository profileRepo;
  final SleepService sleepService;
  final WaterIntakeService waterService;
  final WeightService weightService;
  final ActivityHistoryRepository activityHistoryRepo;

  HealthReportService({
    required this.profileRepo,
    required this.sleepService,
    required this.waterService,
    required this.weightService,
    required this.activityHistoryRepo,
  });

  Future<HealthReportSummary> generateSummary({int days = 30}) async {
    final now = DateTime.now();
    // Whole calendar days, ending today.
    final from = lastNDays(days, now: now).first;
    final to = nextDay(startOfDay(now));

    // 1. Profile (optional: the report still works without it).
    ProfileEntity? profile;
    try {
      profile = (await profileRepo.getProfile()).fold((_) => null, (p) => p);
    } catch (e) {
      debugPrint('Health report: profile unavailable: $e');
    }

    // 2. Sleep
    final sleepLogs = await sleepService.getSleepBetween(from, to);
    double? avgSleepHours;
    int? avgSleepScore;
    if (sleepLogs.isNotEmpty) {
      final totalMinutes = sleepLogs.fold<int>(
        0,
        (sum, s) => sum + s.duration.inMinutes,
      );
      avgSleepHours = (totalMinutes / sleepLogs.length) / 60.0;
      final totalScore = sleepLogs.fold<int>(0, (sum, s) => sum + s.sleepScore);
      avgSleepScore = (totalScore / sleepLogs.length).round();
    }

    // 3. Water: logs are stored per signed-in user.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final waterLogs = userId == null
        ? const <WaterLogCache>[]
        : await waterService.getLogsBetween(userId, from, to);
    final waterByDay = <DateTime, int>{};
    for (final w in waterLogs) {
      waterByDay.update(
        startOfDay(w.timestamp),
        (ml) => ml + w.amountMl,
        ifAbsent: () => w.amountMl,
      );
    }

    // 4. Weight: newest first, so the first entry is the latest; else the
    // latest ever recorded.
    final weightLogs = await weightService.between(from, to);
    final latestWeight =
        weightLogs.firstOrNull?.weightKg ??
        (await weightService.latest())?.weightKg;

    // 5. Activity sessions
    final sessions = await activityHistoryRepo.getSessions();
    final recentSessions = sessions
        .where((s) => !s.startTime.isBefore(from))
        .toList();
    final totalActiveMins =
        recentSessions.fold<int>(0, (sum, s) => sum + s.totalDurationSeconds) ~/
        60;
    final totalDistKm =
        recentSessions.fold<double>(0, (sum, s) => sum + s.totalDistanceMeters) /
        1000.0;

    return HealthReportSummary(
      daysCount: days,
      profile: profile,
      avgSleepHours: avgSleepHours,
      avgSleepScore: avgSleepScore,
      nightsLogged: sleepLogs.length,
      totalWorkouts: recentSessions.length,
      totalActiveMinutes: totalActiveMins,
      totalDistanceKm: totalDistKm.isFinite ? totalDistKm : 0,
      avgWaterMl: averageDailyWater(waterByDay),
      waterDaysLogged: waterByDay.values.where((ml) => ml > 0).length,
      latestWeightKg: latestWeight,
      bloodPressure: profile == null
          ? null
          : reportBloodPressure(
              profile.bloodPressureTop,
              profile.bloodPressureBottom,
            ),
      restingBpm: profile == null ? null : reportRestingBpm(profile.bpm),
    );
  }

  /// Shares [summary] (or a fresh one) as a text file, falling back to
  /// plain text when the file can't be written.
  Future<void> exportAndShareReport({
    int days = 30,
    HealthReportSummary? summary,
  }) async {
    final report = summary ?? await generateSummary(days: days);
    final reportText = report.toClinicalText(unit: await weightService.unit());

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/VitalUp_Doctor_Health_Report_${days}d.txt',
      );
      await file.writeAsString(reportText);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'VitalUp Clinical Health Report ($days Days)',
        text:
            'Attached is my VitalUp clinical health report for medical '
            'consultation.',
      );
    } catch (e) {
      debugPrint('Report file share failed, sharing text: $e');
      await Share.share(
        reportText,
        subject: 'VitalUp Clinical Health Report ($days Days)',
      );
    }
  }
}
