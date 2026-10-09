import 'package:intl/intl.dart';
import 'package:nexus_mobile/core/api/json.dart';

/// Ports of web `routes/library/library.ts`.

const bookStatuses = <(String, String)>[('want', 'Want to read'), ('reading', 'Reading'), ('read', 'Read')];

String bookStatusLabel(String? status) => switch (status) {
  'reading' => 'Reading',
  'read' => 'Read',
  _ => 'Want to read',
};

const bookMatchLabel = {
  'matched': 'Matched to Open Library',
  'no_match': 'Not in Open Library',
  'unmatched': 'Not matched yet',
};

/// "Dune: The Graphic Novel" → ("Dune:", "The Graphic Novel").
(String, String?) splitBookTitle(String title) {
  final m = RegExp(r'^(.+?):\s+(.+)$').firstMatch(title);
  return m == null ? (title, null) : ('${m[1]}:', m[2]);
}

DateTime? parseDay(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value.length == 10 ? '${value}T00:00:00' : value)?.toLocal();
}

String? readableDate(String? value) {
  final d = parseDay(value);
  return d == null ? null : DateFormat('d MMM y').format(d);
}

String bookAuthors(Json book) {
  final catalog = book.obj('catalog');
  final list = catalog?.strings('authors') ?? const [];
  return book.str('authors') ??
      catalog?.str('authors_label') ??
      (list.isNotEmpty ? list.join(', ') : null) ??
      'Unknown author';
}
