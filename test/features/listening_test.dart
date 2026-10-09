import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/features/listening/listening.dart';

void main() {
  test('splitTrackTitle pulls the accent from brackets or a dash', () {
    expect(splitTrackTitle('Time (You and I)'), ('Time', '(You and I)'));
    expect(splitTrackTitle('Heroes - 2017 Remaster'), ('Heroes', '2017 Remaster'));
    expect(splitTrackTitle('Plain'), ('Plain', null));
  });

  test('durations and years', () {
    expect(formatDuration(3 * 60 * 1000 + 59 * 1000), '3 min');
    expect(formatDuration(65 * 60 * 1000), '1 hr 5 min');
    expect(
      totalDuration([
        {'duration_ms': 60000},
        {'duration_ms': 120000},
      ]),
      '3 min',
    );
    expect(releaseYear('2019-04-01'), '2019');
    expect(releaseYear(null), isNull);
  });

  test('plainText strips tags and entities', () {
    expect(plainText('Rock &amp; roll <a href="x">here</a>'), 'Rock & roll here');
    expect(plainText(null), '');
  });

  test('audioMeters clamps and labels known traits only', () {
    final rows = audioMeters({'energy': 1.4, 'valence': .5, 'tempo': 120});
    expect(rows.map((r) => r.label), ['Energy', 'Mood']);
    expect(rows.first.value, 1);
    expect(rows.last.word, '50%');
    expect(audioMeters(null), isEmpty);
  });
}
