import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A photo taken while offline, waiting to be read.
class QueuedCapture {
  const QueuedCapture({required this.id, required this.path, required this.at, this.hint});

  factory QueuedCapture.fromJson(Map<String, dynamic> j) => QueuedCapture(
    id: j['id'] as String,
    path: j['path'] as String,
    hint: j['hint'] as String?,
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
  );

  final String id;
  final String path;
  final String? hint;
  final DateTime at;

  File get file => File(path);

  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'hint': hint, 'at': at.toIso8601String()};
}

final captureQueueProvider = AsyncNotifierProvider<CaptureQueue, List<QueuedCapture>>(CaptureQueue.new);

/// Offline capture queue: photos are copied into app storage and listed in
/// prefs until they're read. Cleared on sign-out so another account on the
/// same device never sees them.
class CaptureQueue extends AsyncNotifier<List<QueuedCapture>> {
  static const _key = 'nx.capture.queue';
  static const maxItems = 20;

  @override
  Future<List<QueuedCapture>> build() async {
    ref.listen(authProvider, (_, next) {
      if (next is SignedOut) unawaited(clear());
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(QueuedCapture.fromJson).toList();
      return [
        for (final q in items)
          if (q.file.existsSync()) q,
      ];
    } on Object {
      return const [];
    }
  }

  Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/capture-queue');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _save(List<QueuedCapture> items) async {
    state = AsyncData(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final q in items) q.toJson()]));
  }

  Future<bool> add(File photo, {String? hint}) async {
    final items = [...await future];
    if (items.length >= maxItems) return false;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final copy = await photo.copy('${(await _dir()).path}/$id.jpg');
    await _save([...items, QueuedCapture(id: id, path: copy.path, hint: hint, at: DateTime.now())]);
    return true;
  }

  Future<void> remove(String id) async {
    final items = [...await future];
    for (final q in items.where((q) => q.id == id)) {
      if (q.file.existsSync()) await q.file.delete();
    }
    await _save([
      for (final q in items)
        if (q.id != id) q,
    ]);
  }

  Future<void> clear() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    await _save(const []);
  }
}
