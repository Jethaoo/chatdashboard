import 'package:flutter_test/flutter_test.dart';
import 'package:chatdashboard/utils/outgoing_message.dart';

void main() {
  group('normalizeOutgoingMessageBody', () {
    test('returns empty for blank', () {
      expect(normalizeOutgoingMessageBody('   '), '');
    });

    test('trims whitespace', () {
      expect(normalizeOutgoingMessageBody('  hi  '), 'hi');
    });

    test('clamps to max length', () {
      final long = List.filled(kMaxOutgoingMessageLength + 10, 'a').join();
      final out = normalizeOutgoingMessageBody(long);
      expect(out.length, kMaxOutgoingMessageLength);
    });
  });
}
