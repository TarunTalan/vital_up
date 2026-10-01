import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

class HealthReportSummary {
  final int daysCount;
  final ProfileEntity? profile;
  final double avgSleepHours;
  final int avgSleepScore;
  final int totalWorkouts;
  final int totalActiveMinutes;
  final double totalDistanceKm;
  final int avgWaterMl;
  final double? latestWeightKg;
  final String bloodPressure;
  final String restingBpm;

  const HealthReportSummary({
    required this.daysCount,
    this.profile,
    required this.avgSleepHours,
    required this.avgSleepScore,
    required this.totalWorkouts,
    required this.totalActiveMinutes,
    required this.totalDistanceKm,
    required this.avgWaterMl,
    this.latestWeightKg,
    required this.bloodPressure,
    required this.restingBpm,
  });

  String toClinicalText() {
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final name = profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Patient';

    final buffer = StringBuffer();
    buffer.writeln('====================================================');
    buffer.writeln('          VITALUP CLINICAL HEALTH REPORT            ');
    buffer.writeln('====================================================');
    buffer.writeln('Patient Name: $name');
    buffer.writeln('Report Date:  $dateStr');
    buffer.writeln('Time Horizon: Last $daysCount Days');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('1. CARDIOVASCULAR & RESTING VITALS:');
    buffer.writeln('   • Blood Pressure:    $bloodPressure mmHg');
    buffer.writeln('   • Resting Heart Rate: $restingBpm BPM');
    if (latestWeightKg != null) {
      buffer.writeln('   • Current Weight:    ${latestWeightKg!.toStringAsFixed(1)} kg');
    }
    if (profile?.healthConditions.isNotEmpty == true) {
      buffer.writeln('   • Medical Conditions: ${profile!.healthConditions}');
    }
    if (profile?.allergies.isNotEmpty == true) {
      buffer.writeln('   • Allergies:         ${profile!.allergies}');
    }
    if (profile?.medicines.isNotEmpty == true) {
      buffer.writeln('   • Current Meds:      ${profile!.medicines}');
    }
    buffer.writeln();
    buffer.writeln('2. SLEEP & RECOVERY:');
    buffer.writeln('   • Avg Daily Sleep:   ${avgSleepHours.toStringAsFixed(1)} hrs/night');
    buffer.writeln('   • Avg Sleep Quality: $avgSleepScore / 100');
    buffer.writeln();
    buffer.writeln('3. PHYSICAL ACTIVITY & CARDIO:');
    buffer.writeln('   • Total Workouts:    $totalWorkouts sessions');
    buffer.writeln('   • Active Minutes:    $totalActiveMinutes mins');
    buffer.writeln('   • Total Distance:    ${totalDistanceKm.toStringAsFixed(2)} km');
    buffer.writeln();
    buffer.writeln('4. HYDRATION:');
    buffer.writeln('   • Avg Daily Intake:  $avgWaterMl ml / day');
    buffer.writeln('====================================================');
    buffer.writeln('Generated automatically by VitalUp Offline Health Engine');
    buffer.writeln('Confidential Medical Document for Doctor Consultation');
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
    final from = now.subtract(Duration(days: days));

    // 1. Profile
    ProfileEntity? profile;
    final profileResult = await profileRepo.getProfile();
    profile = profileResult.getOrElse(() => const ProfileEntity(
          id: '',
          email: '',
          fullName: '',
          username: '',
          dob: '',
          weight: '',
          height: '',
          bloodPressureTop: '',
          bloodPressureBottom: '',
          bpm: '',
          sleep: '',
          oxygenLevel: '',
          healthConditions: '',
          allergies: '',
          medicines: '',
        ));

    // 2. Sleep
    final sleepLogs = await sleepService.getSleepBetween(from, now);
    double avgSleepHours = 7.5;
    int avgSleepScore = 80;
    if (sleepLogs.isNotEmpty) {
      final totalMinutes = sleepLogs.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
      avgSleepHours = (totalMinutes / sleepLogs.length) / 60.0;
      final totalScore = sleepLogs.fold<int>(0, (sum, s) => sum + s.sleepScore);
      avgSleepScore = (totalScore / sleepLogs.length).round();
    }

    // 3. Water
    final waterLogs = await waterService.getLogsBetween('local', from, now);
    int avgWaterMl = 2200;
    if (waterLogs.isNotEmpty) {
      final totalWater = waterLogs.fold<int>(0, (sum, w) => sum + w.amountMl);
      avgWaterMl = (totalWater / days).round();
    }

    // 4. Weight
    final weightLogs = await weightService.between(from, now);
    final latestWeight = weightLogs.isNotEmpty ? weightLogs.last.weightKg : null;

    // 5. Activity sessions
    final sessions = await activityHistoryRepo.getSessions();
    final recentSessions = sessions.where((s) => s.startTime.isAfter(from)).toList();
    final totalWorkouts = recentSessions.length;
    final totalActiveMins = recentSessions.fold<int>(0, (sum, s) => sum + s.totalDurationSeconds) ~/ 60;
    final totalDistKm = recentSessions.fold<double>(0, (sum, s) => sum + s.totalDistanceMeters) / 1000.0;

    final bpTop = profile.bloodPressureTop.isNotEmpty ? profile.bloodPressureTop : '120';
    final bpBottom = profile.bloodPressureBottom.isNotEmpty ? profile.bloodPressureBottom : '80';
    final restingBpm = profile.bpm.isNotEmpty ? profile.bpm : '68';

    return HealthReportSummary(
      daysCount: days,
      profile: profile,
      avgSleepHours: avgSleepHours,
      avgSleepScore: avgSleepScore,
      totalWorkouts: totalWorkouts,
      totalActiveMinutes: totalActiveMins,
      totalDistanceKm: totalDistKm,
      avgWaterMl: avgWaterMl,
      latestWeightKg: latestWeight,
      bloodPressure: '$bpTop/$bpBottom',
      restingBpm: restingBpm,
    );
  }

  Future<void> exportAndShareReport({int days = 30}) async {
    final summary = await generateSummary(days: days);
    final reportText = summary.toClinicalText();

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/VitalUp_Doctor_Health_Report_${days}d.txt');
      await file.writeAsString(reportText);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'VitalUp Clinical Health Report ($days Days)',
        text: 'Attached is my VitalUp clinical health report for medical consultation.',
      );
    } catch (_) {
      // Fallback share as plain text if file writing fails
      await Share.share(
        reportText,
        subject: 'VitalUp Clinical Health Report ($days Days)',
      );
    }
  }
}
