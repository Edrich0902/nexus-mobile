import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seconds each colour-field slide stays before rotating.
const homeCardCycleSeconds = 60;

/// Spread card flips across the cycle so roughly one board face changes at a time.
const homeCardStaggerSlots = 10;

/// Fine clock so staggered cards can flip on different seconds.
final homeCycleClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

int cycleSalt(String key) {
  var h = 0;
  for (final u in key.codeUnits) {
    h = (h * 31 + u) & 0xffff;
  }
  return h;
}

/// Phase offset in seconds — slots are [0, 6, 12, …] within the 60s window.
int cyclePhase(String key) {
  final slot = cycleSalt(key) % homeCardStaggerSlots;
  return slot * (homeCardCycleSeconds ~/ homeCardStaggerSlots);
}

/// Slide index for [key] at [now], staggered by [cyclePhase].
int cycleIndex(int length, DateTime now, String key) {
  if (length <= 1) return 0;
  final elapsed = now.millisecondsSinceEpoch ~/ 1000;
  return ((elapsed + cyclePhase(key)) ~/ homeCardCycleSeconds) % length;
}

T cycleAt<T>(List<T> items, DateTime now, String key) {
  assert(items.isNotEmpty, 'cycleAt requires at least one slide');
  return items[cycleIndex(items.length, now, key)];
}
