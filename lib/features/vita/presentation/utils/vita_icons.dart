import 'package:vital_up/features/vita/domain/entities/vita_insights.dart';

/// Icon assets for the Vita screens (Figma Phosphor icons), kept in one place
/// so they can be swapped without touching the pages.
class VitaIcons {
  VitaIcons._();

  static const String _dir = 'assets/icons';

  // Home feature tiles (24dp, primary cyan).
  static const String dietPlan = '$_dir/vita_carrot.svg';
  static const String healthAnalysis = '$_dir/vita_chart_pie_slice.svg';
  static const String stressGuide = '$_dir/vita_person_tai_chi.svg';
  static const String chat = '$_dir/vita_chat_dots.svg';

  // Health analysis signal badges (20dp, teal).
  static const String diet = '$_dir/vita_fork_knife.svg';
  static const String metrics = '$_dir/vita_pulse.svg';
  static const String sleep = '$_dir/vita_moon_stars.svg';
  static const String stress = '$_dir/vita_smiley_meh.svg';
  static const String activity = '$_dir/vita_person_run.svg';
  static const String medication = '$_dir/vita_pill.svg';

  // Chat + buttons.
  static const String send = '$_dir/vita_paper_plane.svg';
  static const String caretLeft = '$_dir/vita_caret_left.svg';

  static String forSignal(HealthSignalKind kind) => switch (kind) {
        HealthSignalKind.diet => diet,
        HealthSignalKind.metrics => metrics,
        HealthSignalKind.sleep => sleep,
        HealthSignalKind.stress => stress,
        HealthSignalKind.activity => activity,
        HealthSignalKind.medication => medication,
      };
}
