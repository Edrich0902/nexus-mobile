import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/features/admin/admin_screen.dart';
import 'package:nexus_mobile/features/code/github.dart';

void main() {
  group('github helpers', () {
    test('firstLine keeps the commit subject only', () {
      expect(firstLine('Fix bug\n\nLonger body'), 'Fix bug');
      expect(firstLine('  '), '(no message)');
      expect(firstLine(null), '(no message)');
    });

    test('shortSha trims to seven characters', () {
      expect(shortSha('abcdef1234567'), 'abcdef1');
      expect(shortSha('abc'), 'abc');
      expect(shortSha(null), '');
    });

    test('pullState prefers merged, then closed, then draft', () {
      expect(pullState({'state': 'closed', 'merged': true}), PullState.merged);
      expect(pullState({'state': 'closed', 'merged_at': '2026-01-01T00:00:00Z'}), PullState.merged);
      expect(pullState({'state': 'closed'}), PullState.closed);
      expect(pullState({'state': 'open', 'draft': true}), PullState.draft);
      expect(pullState({'state': 'open'}), PullState.open);
    });

    test('titleFromBranch drops the prefix and separators', () {
      expect(titleFromBranch('feature/add-dark_mode'), 'add dark mode');
      expect(titleFromBranch('hotfix'), 'hotfix');
    });
  });

  group('parseUnifiedDiff', () {
    test('numbers old and new lines per hunk', () {
      const patch =
          '@@ -10,3 +10,4 @@ class A\n'
          ' keep\n'
          '-old\n'
          '+new\n'
          '+added\n'
          '\\ No newline at end of file\n'
          '@@ -40,1 +41,1 @@\n'
          '-x\n'
          '+y';
      final hunks = parseUnifiedDiff(patch);
      expect(hunks, hasLength(2));

      final first = hunks.first.lines;
      expect(first.map((l) => l.kind), [DiffKind.context, DiffKind.del, DiffKind.add, DiffKind.add, DiffKind.meta]);
      expect((first[0].oldLine, first[0].newLine), (10, 10));
      expect((first[1].oldLine, first[1].newLine, first[1].text), (11, null, 'old'));
      expect((first[2].oldLine, first[2].newLine, first[2].text), (null, 11, 'new'));
      expect(first[3].newLine, 12);

      expect(hunks.last.header, startsWith('@@ -40,1 +41,1'));
      expect(hunks.last.lines.last.newLine, 41);
    });

    test('ignores preamble before the first hunk', () {
      expect(parseUnifiedDiff('diff --git a/x b/x\nindex 1..2'), isEmpty);
    });
  });

  group('admin helpers', () {
    test('formatBytes scales units', () {
      expect(formatBytes(null), '—');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('formatUptime shows days or hours', () {
      expect(formatUptime(null), '—');
      expect(formatUptime(3 * 3600 + 5 * 60), '3h 5m');
      expect(formatUptime(2 * 86400 + 4 * 3600), '2d 4h');
    });

    test('memoryUsed and diskUsed fall back to totals', () {
      expect(
        memoryUsed({
          'memory': {'system_total_bytes': 1000, 'system_available_bytes': 400},
        }),
        600,
      );
      expect(
        memoryUsed({
          'memory': {'php_usage_bytes': 42},
        }),
        42,
      );
      expect(
        diskUsed({
          'disk': {'total_bytes': 100, 'free_bytes': 30},
        }),
        70,
      );
      expect(diskUsed(null), isNull);
    });

    test('shortClass and share', () {
      expect(shortClass(r'App\Jobs\SyncSpotify'), 'SyncSpotify');
      expect(share(45), .45);
      expect(share(140), 1);
      expect(share(null), isNull);
    });
  });
}
