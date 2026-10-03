import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/home_widget/home_widget_service.dart';

void main() {
  group('HomeWidgetService routeOf deep link tests', () {
    test('parses query parameter route from vitalup://widget/open', () {
      final uri = Uri.parse('vitalup://widget/open?route=water-trends');
      expect(HomeWidgetService.routeOf(uri), 'water-trends');
    });

    test('parses food-scan route', () {
      final uri = Uri.parse('vitalup://widget/open?route=food-scan');
      expect(HomeWidgetService.routeOf(uri), 'food-scan');
    });

    test('parses activity-tracking route', () {
      final uri = Uri.parse('vitalup://widget/open?route=activity-tracking');
      expect(HomeWidgetService.routeOf(uri), 'activity-tracking');
    });

    test('parses vita-chat route', () {
      final uri = Uri.parse('vitalup://widget/open?route=vita-chat');
      expect(HomeWidgetService.routeOf(uri), 'vita-chat');
    });

    test('parses quick-login route', () {
      final uri = Uri.parse('vitalup://widget/quick-login');
      expect(HomeWidgetService.routeOf(uri), 'login');
    });

    test('parses direct host scheme vitalup://login', () {
      final uri = Uri.parse('vitalup://login');
      expect(HomeWidgetService.routeOf(uri), 'login');
    });

    test('parses direct host scheme vitalup://food-scan', () {
      final uri = Uri.parse('vitalup://food-scan');
      expect(HomeWidgetService.routeOf(uri), 'food-scan');
    });

    test('returns null for empty or unsupported uri', () {
      expect(HomeWidgetService.routeOf(null), isNull);
      expect(HomeWidgetService.routeOf(Uri.parse('https://google.com')), isNull);
    });
  });
}
