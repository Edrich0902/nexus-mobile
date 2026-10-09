import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';

/// `GET path` as a Json provider that resets when the user changes.
FutureProvider<Json> jsonProvider(String path, {Map<String, dynamic>? query}) => FutureProvider<Json>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const {};
  return asJson(await ref.watch(apiClientProvider).get(path, query: query));
});

/// Swallows errors into an empty payload — for optional home modules that
/// must never break the page (e.g. GitHub not connected).
FutureProvider<Json> softJsonProvider(String path) => FutureProvider<Json>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const {};
  try {
    return asJson(await ref.watch(apiClientProvider).get(path));
  } on Object {
    return const {};
  }
});
