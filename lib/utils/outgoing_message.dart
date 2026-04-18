/// Must stay aligned with [firestore.rules] message `text` max length.
const int kMaxOutgoingMessageLength = 8000;

/// Trims and clamps body before writing to Firestore.
String normalizeOutgoingMessageBody(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  if (t.length <= kMaxOutgoingMessageLength) return t;
  return t.substring(0, kMaxOutgoingMessageLength);
}
