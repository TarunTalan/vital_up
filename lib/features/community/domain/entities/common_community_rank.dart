import 'package:equatable/equatable.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';

/// Represents a friend's and the current user's rank within a shared/common community.
class CommonCommunityRank extends Equatable {
  final Community community;
  final int? friendRank;
  final int friendPoints;
  final int? myRank;
  final int myPoints;

  const CommonCommunityRank({
    required this.community,
    required this.friendRank,
    this.friendPoints = 0,
    required this.myRank,
    this.myPoints = 0,
  });

  @override
  List<Object?> get props => [
    community,
    friendRank,
    friendPoints,
    myRank,
    myPoints,
  ];
}
