import 'package:intl/intl.dart';

/// "3 min ago", "yesterday", "12 Mar" (web lib/datetime relativeTime).
String relativeTime(DateTime? at, {DateTime? now}) {
  if (at == null) return 'never';
  final n = now ?? DateTime.now();
  final diff = n.difference(at);
  final future = diff.isNegative;
  final d = diff.abs();
  String ago(String s) => future ? 'in $s' : '$s ago';
  if (d.inSeconds < 45) return future ? 'soon' : 'just now';
  if (d.inMinutes < 60) return ago('${d.inMinutes} min');
  if (d.inHours < 24) return ago('${d.inHours} h');
  if (d.inDays == 1) return future ? 'tomorrow' : 'yesterday';
  if (d.inDays < 7) return ago('${d.inDays} days');
  return DateFormat(at.year == n.year ? 'd MMM' : 'd MMM y').format(at);
}

String formatDateTime(DateTime? at) => at == null ? '' : DateFormat('d MMM y, HH:mm').format(at);

String formatDate(DateTime? at) => at == null ? '' : DateFormat('d MMM y').format(at);

String formatTime(DateTime? at) => at == null ? '' : DateFormat('HH:mm').format(at);

/// Stream rail stamp: time today, weekday this week, date otherwise.
String streamStamp(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days == 0) return DateFormat('HH:mm').format(at);
  if (days.abs() < 7) return DateFormat('EEE').format(at);
  return DateFormat('d MMM').format(at);
}

String plural(num n, String word, [String? many]) => '$n ${n == 1 ? word : (many ?? '${word}s')}';

String compactNumber(num n) => NumberFormat.compact().format(n);

/// 1536 → "1.5 KB". Null or NaN render as an em dash.
String formatBytes(num? value) {
  if (value == null || value.isNaN) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var n = value.toDouble();
  var i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i++;
  }
  return '${n.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}
