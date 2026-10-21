/// The health onboarding steps, in order. [id] is what's saved in prefs
/// (`onboarding_current_step`) so the flow resumes where it was left;
/// [routeName] opens the flow at that step.
enum OnboardingStep {
  about('personal_details', 'health-personal-details'),
  height('height', 'health-height'),
  weight('weight', 'health-weight'),
  diet('dietary_preference', 'health-dietary-preference'),
  goal('goals', 'health-goals'),
  activity('activity', 'health-activity'),
  privacy('info', 'health-info-permission');

  final String id;
  final String routeName;
  const OnboardingStep(this.id, this.routeName);

  /// The saved step, or the first one for anything unknown (steps from
  /// older versions, such as "blood_pressure", no longer exist).
  static OnboardingStep fromId(String id) {
    for (final step in values) {
      if (step.id == id) return step;
    }
    return about;
  }

  /// Name, date of birth and gender are needed for every estimate, and the
  /// privacy step is where the answers are saved: neither can be skipped.
  bool get skippable => this != about && this != privacy;

  bool get isFirst => this == values.first;
  bool get isLast => this == values.last;

  /// 1-based position, for "Step 2 of 7".
  int get number => index + 1;

  OnboardingStep? get next => isLast ? null : values[index + 1];
  OnboardingStep? get previous => isFirst ? null : values[index - 1];
}
