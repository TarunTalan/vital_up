import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  final String id;
  final String username;
  final String email;
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
  final String? photoUrl;

  const ProfileEntity({
    required this.id,
    required this.username,
    required this.email,
    this.fullName = '',
    this.dob = '',
    this.gender = '',
    this.weight = '',
    this.weightUnit = 'kg',
    this.height = '',
    this.heightUnit = 'cm',
    this.oxygenLevel = '',
    this.healthConditions = '',
    this.allergies = '',
    this.medicines = '',
    this.smokes = '',
    this.bloodPressureTop = '',
    this.bloodPressureBottom = '',
    this.bpm = '',
    this.activity = '',
    this.sleep = '',
    this.photoUrl,
  });

  ProfileEntity copyWith({
    String? id,
    String? username,
    String? email,
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
    String? photoUrl,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
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
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
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
        photoUrl,
      ];
}
