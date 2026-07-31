import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final double? weightKg;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.weightKg,
  });

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, weightKg];
}
