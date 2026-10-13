import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/theme.dart' show buildNexusTheme;
import 'package:nexus_mobile/design/tokens.g.dart';

/// The ambient engine (web `ambient.ts`): the route picks a section, and any
/// mounted screen can push a temporary override (album art, a wine's style).
@immutable
class AmbientState {
  const new({this.section = SectionKey.home, this.overrides = const []});

  final SectionKey section;
  final List<(int, Ambient)> overrides;

  Ambient get active => overrides.isEmpty ? section.ambient : overrides.last.$2;

  AmbientState copyWith({SectionKey? section, List<(int, Ambient)>? overrides}) =>
      AmbientState(section: section ?? this.section, overrides: overrides ?? this.overrides);
}

final ambientProvider = NotifierProvider<AmbientController, AmbientState>(AmbientController.new);

class AmbientController extends Notifier<AmbientState> {
  int _seq = 0;

  @override
  AmbientState build() => const AmbientState();

  void setSection(SectionKey key) {
    if (state.section != key) state = state.copyWith(section: key);
  }

  int push(Ambient ambient) {
    final id = ++_seq;
    state = state.copyWith(overrides: [...state.overrides, (id, ambient)]);
    return id;
  }

  void update(int id, Ambient ambient) {
    state = state.copyWith(
      overrides: [
        for (final o in state.overrides)
          if (o.$1 == id) (id, ambient) else o,
      ],
    );
  }

  void remove(int id) {
    state = state.copyWith(overrides: state.overrides.where((o) => o.$1 != id).toList());
  }
}

/// Animates the whole app's theme between ambients over 900 ms with the
/// shared ease curve, like the `@property` transition on web.
class AmbientTheme extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(ambientProvider.select((s) => s.active));
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: target.amb,
      ),
      child: AnimatedTheme(
        data: _themeFor(target),
        duration: reduce ? Duration.zero : NxMotion.ambient,
        curve: NxMotion.ease,
        child: child,
      ),
    );
  }
}

final _themeCache = <Ambient, ThemeData>{};

ThemeData _themeFor(Ambient a) => _themeCache.putIfAbsent(a, () {
  if (_themeCache.length > 24) _themeCache.clear();
  return buildNexusTheme(a);
});

/// Tint the app while this widget is mounted. Pass null to fall back to the
/// route's section ambient.
class AmbientOverride extends ConsumerStatefulWidget {
  const new({required this.ambient, required this.child, super.key});

  final Ambient? ambient;
  final Widget child;

  @override
  ConsumerState<AmbientOverride> createState() => _AmbientOverrideState();
}

class _AmbientOverrideState extends ConsumerState<AmbientOverride> {
  int? _id;
  late final AmbientController _controller = ref.read(ambientProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(AmbientOverride old) {
    super.didUpdateWidget(old);
    if (old.ambient != widget.ambient) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    final a = widget.ambient;
    if (a != null) {
      if (_id == null) {
        _id = _controller.push(a);
      } else {
        _controller.update(_id!, a);
      }
    } else if (_id != null) {
      _controller.remove(_id!);
      _id = null;
    }
  }

  @override
  void dispose() {
    final id = _id;
    if (id != null) {
      Future.microtask(() => _controller.remove(id));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
