import 'package:equatable/equatable.dart';

enum SubmissionStatus { initial, submitting, success, error }

class OnboardingData extends Equatable {
  final String fullName;
  final String dob;
  final String gender;
  final String weight;
  final String weightUnit;
  final String height;
  final String heightUnit;
  final String oxygenLevel;
  final String healthConditions;
  final String allergies;
  final String medicines;
  final String smokes;
  final String bloodPressureTop;
  final String bloodPressureBottom;
  final String bpm;
  final String activity;
  final String sleep;
  final String currentStep;
  final SubmissionStatus status;
  final String? errorMessage;

  const OnboardingData({
    this.fullName = "",
    this.dob = "",
    this.gender = "",
    this.weight = "70",
    this.weightUnit = "kg",
    this.height = "",
    this.heightUnit = "cm",
    this.oxygenLevel = "",
    this.healthConditions = "",
    this.allergies = "",
    this.medicines = "",
    this.smokes = "",
    this.bloodPressureTop = "",
    this.bloodPressureBottom = "",
    this.bpm = "",
    this.activity = "",
    this.sleep = "",
    this.currentStep = "loading",
    this.status = SubmissionStatus.initial,
    this.errorMessage,
  });

  OnboardingData copyWith({
    String? fullName,
    String? dob,
    String? gender,
    String? weight,
    String? weightUnit,
    String? height,
    String? heightUnit,
    String? oxygenLevel,
    String? healthConditions,
    String? allergies,
    String? medicines,
    String? smokes,
    String? bloodPressureTop,
    String? bloodPressureBottom,
    String? bpm,
    String? activity,
    String? sleep,
    String? currentStep,
    SubmissionStatus? status,
    String? errorMessage,
  }) {
    return OnboardingData(
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      oxygenLevel: oxygenLevel ?? this.oxygenLevel,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      medicines: medicines ?? this.medicines,
      smokes: smokes ?? this.smokes,
      bloodPressureTop: bloodPressureTop ?? this.bloodPressureTop,
      bloodPressureBottom: bloodPressureBottom ?? this.bloodPressureBottom,
      bpm: bpm ?? this.bpm,
      activity: activity ?? this.activity,
      sleep: sleep ?? this.sleep,
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        dob,
        gender,
        weight,
        weightUnit,
        height,
        heightUnit,
        oxygenLevel,
        healthConditions,
        allergies,
        medicines,
        smokes,
        bloodPressureTop,
        bloodPressureBottom,
        bpm,
        activity,
        sleep,
        currentStep,
        status,
        errorMessage,
      ];
}
