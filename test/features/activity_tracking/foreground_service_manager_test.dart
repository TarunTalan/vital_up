import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';

void main() {
  test('only Pause / Resume from the service reach the workout', () async {
    final presses = <String>[];
    final sub = ForegroundServiceManager.buttonPresses.listen(presses.add);
    addTearDown(sub.cancel);

    ForegroundServiceManager.handleTaskData(ForegroundServiceManager.pauseButton);
    ForegroundServiceManager.handleTaskData('something else');
    ForegroundServiceManager.handleTaskData({'text': 'Paused'});
    ForegroundServiceManager.handleTaskData(
      ForegroundServiceManager.resumeButton,
    );
    await Future<void>.delayed(Duration.zero);

    expect(presses, [
      ForegroundServiceManager.pauseButton,
      ForegroundServiceManager.resumeButton,
    ]);
  });
}
