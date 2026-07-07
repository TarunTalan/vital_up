import 'package:equatable/equatable.dart';

class MealRecommendation extends Equatable {
  final String message;
  final List<String> reasonTags;

  const MealRecommendation({
    required this.message,
    required this.reasonTags,
  });

  MealRecommendation copyWith({
    String? message,
    List<String>? reasonTags,
  }) {
    return MealRecommendation(
      message: message ?? this.message,
      reasonTags: reasonTags ?? this.reasonTags,
    );
  }

  @override
  List<Object?> get props => [message, reasonTags];
}
