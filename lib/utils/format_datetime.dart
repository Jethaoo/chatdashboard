/// Short local date/time for lists (avoids a full intl dependency).
String formatShortDateTime(DateTime utcOrLocal) {
  final l = utcOrLocal.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

bool isSameCalendarDate(DateTime a, DateTime b) {
  final al = a.toLocal();
  final bl = b.toLocal();
  return al.year == bl.year && al.month == bl.month && al.day == bl.day;
}

String formatMessageTime(DateTime utcOrLocal) {
  final l = utcOrLocal.toLocal();
  final hour12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final minute = l.minute.toString().padLeft(2, '0');
  final suffix = l.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $suffix';
}

String formatChatDateLabel(DateTime utcOrLocal, {DateTime? now}) {
  final l = utcOrLocal.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final target = DateTime(l.year, l.month, l.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${l.month}/${l.day}/${l.year}';
}
