import 'package:flutter_test/flutter_test.dart';
import 'package:chatdashboard/utils/format_datetime.dart';

void main() {
  group('formatShortDateTime', () {
    test('pads month, day, hour, minute', () {
      // Local DateTime so expectations do not depend on the machine TZ offset.
      final s = formatShortDateTime(DateTime(2026, 3, 5, 8, 9));
      expect(s, '2026-03-05 08:09');
    });
  });
}
