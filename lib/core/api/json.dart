/// Loose JSON access for API payloads.
///
/// Most screens render API data directly, so instead of a model class per
/// endpoint they read fields through these null-safe accessors. Core shapes
/// that carry behaviour (session, user, media) get real classes.
typedef Json = Map<String, dynamic>;

extension JsonRead on Json {
  String? str(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  String text(String key, [String fallback = '']) => str(key) ?? fallback;

  int? integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? number(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool flag(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return false;
  }

  Json? obj(String key) {
    final v = this[key];
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  List<Json> list(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.whereType<Map<dynamic, dynamic>>().map((m) => m.cast<String, dynamic>()).toList();
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.where((e) => e != null).map((e) => e.toString()).toList();
  }

  DateTime? date(String key) {
    final s = str(key);
    return s == null ? null : DateTime.tryParse(s)?.toLocal();
  }

  /// Dotted path lookup: `j.at('item.album.name')`.
  dynamic at(String path) {
    dynamic cur = this;
    for (final part in path.split('.')) {
      if (cur is Map) {
        cur = cur[part];
      } else if (cur is List) {
        final i = int.tryParse(part);
        cur = i != null && i < cur.length ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }
}

List<Json> asJsonList(dynamic data) {
  if (data is List) {
    return data.whereType<Map<dynamic, dynamic>>().map((m) => m.cast<String, dynamic>()).toList();
  }
  if (data is Map && data['data'] is List) return asJsonList(data['data']);
  return const [];
}

Json asJson(dynamic data) => data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

/// Laravel paginator envelope.
class Page<T> {
  const new({required this.items, required this.currentPage, required this.lastPage, required this.total});

  factory fromJson(Json json, T Function(Json) map) {
    final meta = json.obj('meta') ?? json;
    return Page(
      items: asJsonList(json['data']).map(map).toList(),
      currentPage: meta.integer('current_page') ?? 1,
      lastPage: meta.integer('last_page') ?? 1,
      total: meta.integer('total') ?? 0,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
