import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';

typedef TrackSample = ({int t, double x, double y});
typedef ReplayCar = ({int number, String code, Color colour});

/// Replay payload pre-processed once: samples per car sorted by time and the
/// shared timeline, so each frame is a binary search per car.
class ReplayModel {
  ReplayModel._(this.tracks, this.times, this.cars, this.bounds);

  factory ReplayModel.from(Json payload) {
    final tracks = <int, List<TrackSample>>{};
    for (final row in payload.list('location')) {
      final t = DateTime.tryParse(row.text('date'))?.millisecondsSinceEpoch;
      final (n, x, y) = (row.integer('driver_number'), row.number('x'), row.number('y'));
      if (t == null || n == null || x == null || y == null) continue;
      tracks.putIfAbsent(n, () => []).add((t: t, x: x, y: y));
    }
    for (final list in tracks.values) {
      list.sort((a, b) => a.t.compareTo(b.t));
    }
    final times = {for (final list in tracks.values) ...list.map((s) => s.t)}.toList()..sort();
    final cars = [
      for (final d in payload.list('drivers'))
        if (tracks.containsKey(d.integer('driver_number')))
          (
            number: d.integer('driver_number')!,
            code: d.str('name_acronym') ?? '#${d.integer('driver_number')}',
            colour: d.str('team_colour') == null ? const Color(0xFFE8E8E8) : teamColour(d.str('team_colour')),
          ),
    ];
    final b = payload.obj('bounds');
    final bounds = b == null
        ? null
        : Rect.fromLTRB(b.number('min_x') ?? 0, b.number('min_y') ?? 0, b.number('max_x') ?? 1, b.number('max_y') ?? 1);
    return ReplayModel._(tracks, times, cars, bounds);
  }

  final Map<int, List<TrackSample>> tracks;
  final List<int> times;
  final List<ReplayCar> cars;
  final Rect? bounds;

  bool get isEmpty => times.isEmpty || bounds == null;

  /// The longest trace stands in for the circuit outline.
  List<TrackSample> get outline =>
      tracks.values.fold<List<TrackSample>>(const [], (best, l) => l.length > best.length ? l : best);

  /// Last known sample at or before [t].
  static TrackSample? positionAt(List<TrackSample> list, int t) {
    var (lo, hi, found) = (0, list.length - 1, -1);
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].t <= t) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found >= 0 ? list[found] : null;
  }
}

/// Web NexusF1TrackReplay: the circuit traced from location data, a dot per
/// car, play / scrub, and car chips to focus one driver.
class F1TrackReplay extends StatefulWidget {
  const F1TrackReplay({required this.model, required this.focus, required this.onFocus, super.key});

  final ReplayModel model;
  final int? focus;
  final ValueChanged<int?> onFocus;

  @override
  State<F1TrackReplay> createState() => _F1TrackReplayState();
}

class _F1TrackReplayState extends State<F1TrackReplay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  int _scrub = 0;

  int get _max => widget.model.times.isEmpty ? 0 : widget.model.times.length - 1;

  @override
  void didUpdateWidget(F1TrackReplay old) {
    super.didUpdateWidget(old);
    if (_scrub > _max) _scrub = _max;
  }

  void _tick(Duration elapsed) {
    if (elapsed - _last < const Duration(milliseconds: 40)) return;
    _last = elapsed;
    if (_scrub >= _max) {
      _ticker.stop();
      setState(() {});
      return;
    }
    setState(() => _scrub++);
  }

  void _toggle() {
    setState(() {
      if (_ticker.isActive) {
        _ticker.stop();
      } else {
        if (_scrub >= _max) _scrub = 0;
        _last = Duration.zero;
        _ticker.start();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final m = widget.model;
    final t = m.times.isEmpty ? null : m.times[_scrub.clamp(0, _max)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(NxRadius.lg),
          child: ColoredBox(
            color: c.surface,
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _TrackPainter(model: m, time: t ?? 0, focus: widget.focus, ink: c.ink),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NxIconButton(
              _ticker.isActive ? LucideIcons.pause : LucideIcons.play,
              tooltip: _ticker.isActive ? 'Pause' : 'Play',
              filled: true,
              onPressed: _toggle,
            ),
            Expanded(
              child: Slider(
                value: _scrub.clamp(0, _max).toDouble(),
                max: _max.toDouble().clamp(1, double.infinity),
                activeColor: c.acc,
                inactiveColor: c.tint2,
                label: 'Replay position',
                onChanged: _max == 0 ? null : (v) => setState(() => _scrub = v.round()),
              ),
            ),
            Text(
              t == null ? '—' : DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(t)),
              style: NxText.mono(color: c.ink2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final car in m.cars)
              NxPressable(
                onTap: () => widget.onFocus(widget.focus == car.number ? null : car.number),
                child: AnimatedContainer(
                  duration: NxMotion.hover,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.focus == car.number ? c.ink : c.tint,
                    borderRadius: BorderRadius.circular(NxRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: car.colour, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        car.code,
                        style: NxText.mono(
                          size: 12,
                          weight: FontWeight.w600,
                          color: widget.focus == car.number ? c.amb : c.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.model, required this.time, required this.focus, required this.ink});

  final ReplayModel model;
  final int time;
  final int? focus;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final b = model.bounds;
    if (b == null || model.times.isEmpty) return;
    const pad = 24.0;
    final scale = [
      (size.width - pad * 2) / (b.width <= 0 ? 1 : b.width),
      (size.height - pad * 2) / (b.height <= 0 ? 1 : b.height),
    ].reduce((a, v) => a < v ? a : v);
    final offX = (size.width - b.width * scale) / 2;
    final offY = (size.height - b.height * scale) / 2;
    Offset project(double x, double y) => Offset(offX + (x - b.left) * scale, size.height - offY - (y - b.top) * scale);

    final outline = model.outline;
    if (outline.isNotEmpty) {
      final path = Path()
        ..moveTo(project(outline.first.x, outline.first.y).dx, project(outline.first.x, outline.first.y).dy);
      for (final p in outline.skip(1)) {
        final o = project(p.x, p.y);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final colours = {for (final c in model.cars) c.number: c};
    void dot(int number, Offset at) {
      final isFocus = focus == number;
      final car = colours[number];
      canvas.drawCircle(
        at,
        isFocus ? 7 : 5,
        Paint()..color = (car?.colour ?? ink).withValues(alpha: focus == null || isFocus ? 1 : .45),
      );
      if (!isFocus) return;
      canvas.drawCircle(
        at,
        7,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      TextPainter(
          text: TextSpan(
            text: car?.code ?? '',
            style: NxText.mono(size: 11, weight: FontWeight.w600, color: ink),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, at + const Offset(11, -7));
    }

    Offset? focused;
    for (final MapEntry(key: number, value: list) in model.tracks.entries) {
      final pos = ReplayModel.positionAt(list, time);
      if (pos == null) continue;
      final at = project(pos.x, pos.y);
      if (number == focus) {
        focused = at;
      } else {
        dot(number, at);
      }
    }
    if (focused != null && focus != null) dot(focus!, focused);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.time != time || old.focus != focus || old.model != model || old.ink != ink;
}
