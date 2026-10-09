import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/integrations/oauth_connect.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

// ── Helpers (web routes/github/code.ts) ───────────────────────────────────

/// GitHub's own language colours for the common cases.
const _languageColours = {
  'TypeScript': Color(0xFF3178C6),
  'JavaScript': Color(0xFFF1E05A),
  'Vue': Color(0xFF41B883),
  'PHP': Color(0xFF4F5D95),
  'Blade': Color(0xFFF7523F),
  'Python': Color(0xFF3572A5),
  'Go': Color(0xFF00ADD8),
  'Rust': Color(0xFFDEA584),
  'Swift': Color(0xFFF05138),
  'Kotlin': Color(0xFFA97BFF),
  'Java': Color(0xFFB07219),
  'C#': Color(0xFF178600),
  'Dart': Color(0xFF00B4AB),
  'Ruby': Color(0xFF701516),
  'Shell': Color(0xFF89E051),
  'CSS': Color(0xFF663399),
  'SCSS': Color(0xFFC6538C),
  'HTML': Color(0xFFE34C26),
};

Color? languageColour(String? language) => _languageColours[language];

String firstLine(String? message) {
  final line = (message ?? '').split('\n').first.trim();
  return line.isEmpty ? '(no message)' : line;
}

String shortSha(String? sha) => sha == null ? '' : sha.substring(0, sha.length < 7 ? sha.length : 7);

enum PullState {
  open('Open'),
  draft('Draft'),
  merged('Merged'),
  closed('Closed');

  const PullState(this.label);

  final String label;
}

PullState pullState(Json pull) {
  if (pull.flag('merged') || pull.str('merged_at') != null) return PullState.merged;
  if (pull.str('state') == 'closed') return PullState.closed;
  return pull.flag('draft') ? PullState.draft : PullState.open;
}

const pullFilters = [('open', 'Open'), ('merged', 'Merged'), ('closed', 'Closed'), ('all', 'All')];

/// "feature/add-thing" → "add thing" for a new pull request title.
String titleFromBranch(String branch) => branch.replaceFirst(RegExp(r'^[\w-]+/'), '').replaceAll(RegExp('[-_]+'), ' ');

// ── Unified diff ───────────────────────────────────────────────────────────

enum DiffKind { context, add, del, meta }

typedef DiffLine = ({DiffKind kind, int? oldLine, int? newLine, String text});
typedef DiffHunk = ({String header, List<DiffLine> lines});

final _hunkHeader = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$');

/// Parses a GitHub file `patch` into hunks with old / new line numbers.
List<DiffHunk> parseUnifiedDiff(String patch) {
  final hunks = <DiffHunk>[];
  List<DiffLine>? lines;
  var (oldNo, newNo) = (0, 0);
  for (final raw in patch.split('\n')) {
    final m = _hunkHeader.firstMatch(raw);
    if (m != null) {
      lines = [];
      hunks.add((header: raw, lines: lines));
      oldNo = int.parse(m[1]!);
      newNo = int.parse(m[2]!);
      continue;
    }
    if (lines == null) continue;
    if (raw.startsWith('+')) {
      lines.add((kind: DiffKind.add, oldLine: null, newLine: newNo++, text: raw.substring(1)));
    } else if (raw.startsWith('-')) {
      lines.add((kind: DiffKind.del, oldLine: oldNo++, newLine: null, text: raw.substring(1)));
    } else if (raw.startsWith(r'\')) {
      lines.add((kind: DiffKind.meta, oldLine: null, newLine: null, text: raw));
    } else {
      lines.add((
        kind: DiffKind.context,
        oldLine: oldNo++,
        newLine: newNo++,
        text: raw.isEmpty ? '' : raw.substring(1),
      ));
    }
  }
  return hunks;
}

// ── Data ───────────────────────────────────────────────────────────────────

typedef RepoKey = ({String owner, String repo});
typedef PullKey = ({String owner, String repo, int number});

final githubApiProvider = Provider(GithubApi.new);

class GithubApi {
  GithubApi(this._ref);

  final Ref _ref;
  static const _b = '/github';

  ApiClient get _api => _ref.read(apiClientProvider);

  String _r(String owner, String repo) => '$_b/repos/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(repo)}';

  Future<String> connectUrl({String? returnTo}) async =>
      asJson(await _api.get('$_b/connect', query: {'return_to': returnTo})).text('url');
  Future<void> disconnect() => _api.post('$_b/disconnect');
  Future<String> sync() async => asJson(await _api.post('$_b/sync')).text('message', 'Sync queued');

  Future<Json> profile() async => asJson(await _api.get('$_b/me'));
  Future<Json> stats({bool refresh = false}) async =>
      asJson(await _api.get('$_b/stats', query: {'refresh': refresh ? 1 : null}));
  Future<List<Json>> repos() async => asJsonList(await _api.get('$_b/repos'));
  Future<Json> repo(String owner, String repo) async => asJson(await _api.get(_r(owner, repo)));
  Future<bool> setStar(String owner, String repo, {required bool starred}) async {
    final res = starred ? await _api.post('${_r(owner, repo)}/star') : await _api.delete('${_r(owner, repo)}/star');
    return asJson(res).flag('starred');
  }

  Future<Json> search(String q, String type) async =>
      asJson(await _api.get('$_b/search', query: {'q': q, 'type': type, 'page': 1, 'per_page': 20}));

  Future<List<Json>> branches(String owner, String repo) async =>
      asJson(await _api.get('${_r(owner, repo)}/branches')).list('items');
  Future<void> createBranch(String owner, String repo, {required String name, String? from}) =>
      _api.post('${_r(owner, repo)}/branches', data: {'name': name, 'from': from});
  Future<void> deleteBranch(String owner, String repo, String branch) =>
      _api.delete('${_r(owner, repo)}/branches/${Uri.encodeComponent(branch)}');

  Future<List<Json>> commits(String owner, String repo) async =>
      asJson(await _api.get('${_r(owner, repo)}/commits', query: {'per_page': 30})).list('items');
  Future<Json> compare(String owner, String repo, String base, String head) async =>
      asJson(await _api.get('${_r(owner, repo)}/compare', query: {'base': base, 'head': head}));

  Future<List<Json>> inbox(String state) async =>
      asJson(await _api.get('$_b/pulls', query: {'state': state, 'per_page': 40})).list('items');
  Future<List<Json>> repoPulls(String owner, String repo, String state) async =>
      asJson(await _api.get('${_r(owner, repo)}/pulls', query: {'state': state, 'per_page': 40})).list('items');

  Future<Json> pull(PullKey k) async => asJson(await _api.get('${_r(k.owner, k.repo)}/pulls/${k.number}'));
  Future<List<Json>> pullFiles(PullKey k) async =>
      asJson(await _api.get('${_r(k.owner, k.repo)}/pulls/${k.number}/files')).list('items');
  Future<List<Json>> pullReviews(PullKey k) async =>
      asJson(await _api.get('${_r(k.owner, k.repo)}/pulls/${k.number}/reviews')).list('items');

  Future<Json> createPull(
    String owner,
    String repo, {
    required String title,
    required String head,
    required String base,
    String? body,
    bool draft = false,
  }) async => asJson(
    await _api.post(
      '${_r(owner, repo)}/pulls',
      data: {'title': title, 'head': head, 'base': base, 'body': body, 'draft': draft},
    ),
  );

  Future<Json> merge(PullKey k, String method) async =>
      asJson(await _api.put('${_r(k.owner, k.repo)}/pulls/${k.number}/merge', data: {'merge_method': method}));
  Future<void> markReady(PullKey k) => _api.post('${_r(k.owner, k.repo)}/pulls/${k.number}/ready');
  Future<void> convertToDraft(PullKey k) => _api.post('${_r(k.owner, k.repo)}/pulls/${k.number}/draft');
  Future<void> review(PullKey k, {required String event, String? body}) =>
      _api.post('${_r(k.owner, k.repo)}/pulls/${k.number}/reviews', data: {'event': event, 'body': body});
}

bool githubConnected(WidgetRef ref) => ref.watch(githubStatusProvider).value?.flag('connected') ?? false;

final githubProfileProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(githubApiProvider).profile());

final githubReposProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(githubApiProvider).repos());

final githubStatsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(githubApiProvider).stats());

final githubInboxProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, state) => ref.watch(githubApiProvider).inbox(state),
);

final githubRepoProvider = FutureProvider.autoDispose.family<Json, RepoKey>(
  (ref, k) => ref.watch(githubApiProvider).repo(k.owner, k.repo),
);

final githubRepoPullsProvider = FutureProvider.autoDispose.family<List<Json>, (RepoKey, String)>(
  (ref, k) => ref.watch(githubApiProvider).repoPulls(k.$1.owner, k.$1.repo, k.$2),
);

final githubCommitsProvider = FutureProvider.autoDispose.family<List<Json>, RepoKey>(
  (ref, k) => ref.watch(githubApiProvider).commits(k.owner, k.repo),
);

final githubBranchesProvider = FutureProvider.autoDispose.family<List<Json>, RepoKey>(
  (ref, k) => ref.watch(githubApiProvider).branches(k.owner, k.repo),
);

/// Pull request, its changed files and reviews (web loadPullDetail).
final githubPullProvider = FutureProvider.autoDispose
    .family<({Json pull, List<Json> files, List<Json> reviews}), PullKey>((
      ref,
      k,
    ) async {
      final api = ref.watch(githubApiProvider);
      final (pull, files, reviews) = await (api.pull(k), api.pullFiles(k), api.pullReviews(k)).wait;
      return (pull: pull, files: files, reviews: reviews);
    });

void refreshGithub(WidgetRef ref) => ref
  ..invalidate(githubStatusProvider)
  ..invalidate(githubPulseProvider)
  ..invalidate(githubProfileProvider)
  ..invalidate(githubReposProvider)
  ..invalidate(githubStatsProvider);

Future<void> connectGithub(BuildContext context, WidgetRef ref) async {
  final api = ref.read(githubApiProvider);
  final ok = await connectWithOAuth(
    context,
    provider: 'github',
    authorizationUrl: (returnTo) => api.connectUrl(returnTo: returnTo),
  );
  if (!ok) return;
  refreshGithub(ref);
  try {
    await api.sync();
  } on Object {
    // The first sync also runs on the API side after connect.
  }
  if (context.mounted) showNxToast(context, 'GitHub connected. Your repositories sync in the background.');
}

Future<void> syncGithub(BuildContext context, WidgetRef ref) async {
  try {
    final message = await ref.read(githubApiProvider).sync();
    refreshGithub(ref);
    if (context.mounted) showNxToast(context, message);
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Could not start a sync.');
  }
}

Future<void> disconnectGithub(BuildContext context, WidgetRef ref) async {
  final ok = await showNxConfirm(context, message: 'Disconnect GitHub from Nexus?', confirmLabel: 'Disconnect');
  if (!ok) return;
  try {
    await ref.read(githubApiProvider).disconnect();
    refreshGithub(ref);
    if (context.mounted) showNxToast(context, 'GitHub disconnected.');
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Could not disconnect.');
  }
}
