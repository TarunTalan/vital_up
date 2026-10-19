import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/community/presentation/widgets/common_communities_section.dart';

void main() {
  test('who is ahead between two ranks', () {
    expect(compareRanks(null, null), isNull);
    expect(compareRanks(3, 8), greaterThan(0));
    expect(compareRanks(8, 3), lessThan(0));
    expect(compareRanks(5, 5), 0);
    // Being ranked beats not being ranked.
    expect(compareRanks(40, null), greaterThan(0));
    expect(compareRanks(null, 40), lessThan(0));
  });
}
