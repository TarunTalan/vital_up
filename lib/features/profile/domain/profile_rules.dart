import 'package:vital_up/core/utils/input_rules.dart';

/// Validation shared by onboarding and the profile pages: name, date of
/// birth (stored as "ddMMyyyy") and body measurements. Messages are short
/// and shown inline under the field.
abstract final class ProfileRules {
  /// Letters (any language), spaces, apostrophes, hyphens and dots, starting
  /// with a letter: "Anne-Marie", "O'Brien", "José", "J. R.".
  static final _name = RegExp(r"^\p{L}[\p{L}\p{M} '.\-]*$", unicode: true);

  /// The cleaned name to save.
  static String cleanName(String input) =>
      sanitizeText(input, maxLength: InputLimits.name);

  /// Why [input] isn't a usable full name, or null.
  static String? nameError(String input) {
    final name = cleanName(input);
    if (name.isEmpty) return 'Enter your name';
    if (name.length < 2) return 'Use at least 2 characters';
    if (!_name.hasMatch(name)) return 'Use letters, spaces, hyphens or apostrophes';
    return null;
  }

  /// Strictly parses "ddMMyyyy"; null for impossible dates like 31/02.
  static DateTime? parseDob(String raw) {
    if (raw.length != 8) return null;
    final day = int.tryParse(raw.substring(0, 2));
    final month = int.tryParse(raw.substring(2, 4));
    final year = int.tryParse(raw.substring(4));
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    // DateTime rolls 31/02 over into March; reject that.
    if (date.day != day || date.month != month) return null;
    return date;
  }

  /// "ddMMyyyy" for [date].
  static String formatDob(DateTime date) =>
      '${_two(date.day)}${_two(date.month)}${date.year.toString().padLeft(4, '0')}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Whole years between [dob] and [now] (a 29 Feb birthday turns a year
  /// older on 1 Mar in non-leap years).
  static int ageOn(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Age from a stored "ddMMyyyy" date, or null if it's missing, invalid,
  /// in the future or outside the supported age range.
  static int? ageFromDob(String raw, {DateTime? now}) {
    final dob = parseDob(raw);
    if (dob == null) return null;
    final age = ageOn(dob, now ?? DateTime.now());
    if (age < 0 || age > InputLimits.ageMax) return null;
    return age;
  }

  /// Why [raw] isn't an acceptable date of birth, or null.
  static String? dobError(String raw, {DateTime? now}) {
    if (raw.isEmpty) return 'Add your date of birth';
    final dob = parseDob(raw);
    if (dob == null) return 'Enter a valid date';
    final today = now ?? DateTime.now();
    if (dob.isAfter(today)) return "Date of birth can't be in the future";
    final age = ageOn(dob, today);
    if (age < InputLimits.ageMin) {
      return 'You must be at least ${InputLimits.ageMin} years old';
    }
    if (age > InputLimits.ageMax) return 'Enter a valid date';
    return null;
  }

  /// Earliest selectable birthday (oldest supported age).
  static DateTime firstDob(DateTime now) =>
      _yearsBefore(now, InputLimits.ageMax);

  /// Latest selectable birthday (youngest supported age).
  static DateTime lastDob(DateTime now) =>
      _yearsBefore(now, InputLimits.ageMin);

  /// [date] clamped into the picker range, so showDatePicker never asserts.
  static DateTime clampDob(DateTime date, DateTime now) {
    final first = firstDob(now);
    final last = lastDob(now);
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  /// Same day [years] earlier; 29 Feb falls back to 28 Feb.
  static DateTime _yearsBefore(DateTime now, int years) {
    final year = now.year - years;
    final lastDay = DateTime(year, now.month + 1, 0).day;
    final day = now.day > lastDay ? lastDay : now.day;
    return DateTime(year, now.month, day);
  }

  /// Why a height of [cm] is out of range, or null.
  static String? heightError(double? cm) {
    if (cm == null) return 'Enter your height';
    if (cm < InputLimits.heightCmMin || cm > InputLimits.heightCmMax) {
      return 'Enter a height between '
          '${InputLimits.heightCmMin.round()} and '
          '${InputLimits.heightCmMax.round()} cm';
    }
    return null;
  }

  /// Why a weight of [kg] is out of range, or null.
  static String? weightError(double? kg) {
    if (kg == null) return 'Enter your weight';
    if (kg < InputLimits.weightKgMin || kg > InputLimits.weightKgMax) {
      return 'Enter a weight between '
          '${InputLimits.weightKgMin.round()} and '
          '${InputLimits.weightKgMax.round()} kg';
    }
    return null;
  }

  /// Cleans a comma-separated medical history list (conditions, allergies,
  /// medicines) for saving.
  static String cleanNote(String input) =>
      sanitizeText(input, maxLength: InputLimits.note);
}
