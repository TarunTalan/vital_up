import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';

class GetSessionHistory {
  final ActivityRepository repository;

  GetSessionHistory(this.repository);

  Future<List<ActivitySession>> call() {
    return repository.getSessions();
  }
}
