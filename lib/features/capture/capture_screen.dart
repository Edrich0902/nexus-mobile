import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/connectivity.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/media/media_upload.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/capture/capture_api.dart';
import 'package:nexus_mobile/features/capture/capture_queue.dart';
import 'package:nexus_mobile/features/capture/capture_review.dart';
import 'package:nexus_mobile/features/collections/drink_forms.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';
import 'package:nexus_mobile/features/library/book_sheets.dart';

const _night = Color(0xFF141012);
const _glass = Color(0x9E1A090D);
const _rose = Color(0xFFE58A98);
const _blush = Color(0xFFF6E8EA);

enum CaptureMode {
  auto('Auto', null, 'Label, can or cover · hold steady', ('Point at a ', 'label', ', can or cover')),
  wine('Wine', 'wine', 'Wine label · hold steady', ('Point at the ', 'label', '')),
  beer('Beer', 'beer', 'Can or bottle label · hold steady', ('Point at the ', 'can', ' or bottle')),
  spirit('Spirit', 'spirit', 'Bottle label · hold steady', ('Point at the ', 'bottle', '')),
  book('Book', 'book', 'Front cover · hold steady', ('Point at the ', 'cover', '')),
  barcode('Barcode', null, 'Line up the ISBN barcode', ('Scan the ', 'barcode', ' on the back'));

  new(this.label, this.hint, this.aim, this.caption);

  final String label;

  /// Sent to `/capture/identify` to steer the label reader.
  final String? hint;
  final String aim;
  final (String, String, String) caption;

  static CaptureMode from(String? kind, {bool barcode = false}) =>
      barcode ? CaptureMode.barcode : CaptureMode.values.firstWhere((m) => m.hint == kind, orElse: () => auto);
}

/// Book barcodes are EAN-13 with a 978/979 "Bookland" prefix (or a bare
/// ISBN-10); anything else is a product code Open Library can't resolve.
String? isbnFromBarcode(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();
  if (digits.length == 13 && (digits.startsWith('978') || digits.startsWith('979'))) return digits;
  if (digits.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(digits)) return digits;
  return null;
}

enum _Stage { aim, reading, review, failed }

/// Phone-only capture (mockup "Capture"): live camera with mode pills, label
/// identification and review, ISBN scanning, and an offline queue.
class CaptureScreen extends ConsumerStatefulWidget {
  const new({this.kind, this.barcode = false, super.key});

  final String? kind;
  final bool barcode;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  late CaptureMode _mode = CaptureMode.from(widget.kind, barcode: widget.barcode);
  CameraController? _cam;
  MobileScannerController? _scanner;
  String? _camError;
  bool _torch = false;
  bool _flash = false;
  bool _scanBusy = false;
  String? _scanNote;
  Timer? _scanNoteTimer;

  _Stage _stage = _Stage.aim;
  File? _shot;
  File? _lastShot;
  double _progress = 0;
  CaptureResult? _result;
  ApiError? _error;

  bool get _isBarcode => _mode == CaptureMode.barcode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startPreview());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanNoteTimer?.cancel();
    unawaited(_cam?.dispose());
    unawaited(_scanner?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isBarcode) return;
    if (state == AppLifecycleState.inactive) {
      final cam = _cam;
      if (cam != null) {
        setState(() => _cam = null);
        unawaited(cam.dispose());
      }
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      unawaited(_initCamera());
    }
  }

  Future<void> _startPreview() async {
    if (_isBarcode) {
      setState(
        () => _scanner = MobileScannerController(
          formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
          detectionSpeed: DetectionSpeed.noDuplicates,
        ),
      );
    } else {
      await _initCamera();
    }
  }

  Future<void> _stopPreview() async {
    final (cam, scanner) = (_cam, _scanner);
    setState(() {
      _cam = null;
      _scanner = null;
    });
    await cam?.dispose();
    await scanner?.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'No camera');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final cam = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await cam.initialize();
      if (!mounted || _isBarcode) {
        await cam.dispose();
        return;
      }
      setState(() {
        _cam = cam;
        _camError = null;
        _torch = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _camError = e.code.contains('Access')
            ? 'Camera access is off. Allow it in Settings, or choose a photo instead.'
            : 'No camera available here. Choose a photo instead.',
      );
    }
  }

  Future<void> _setMode(CaptureMode mode) async {
    if (mode == _mode) return;
    final switching = (mode == CaptureMode.barcode) != _isBarcode;
    if (switching) await _stopPreview();
    setState(() {
      _mode = mode;
      _torch = false;
    });
    if (switching) await _startPreview();
  }

  Future<void> _toggleTorch() async {
    try {
      if (_isBarcode) {
        await _scanner?.toggleTorch();
      } else {
        await _cam?.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      }
      setState(() => _torch = !_torch);
    } on Object {
      // No torch on this device.
    }
  }

  Future<void> _shoot() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _flash = true);
    try {
      final photo = await cam.takePicture();
      if (mounted) setState(() => _flash = false);
      await _identify(File(photo.path));
    } on CameraException {
      if (!mounted) return;
      setState(() => _flash = false);
      showNxToast(context, 'Could not take the photo.', error: true);
    }
  }

  Future<void> _pickFromLibrary() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (picked != null && mounted) await _identify(File(picked.path));
  }

  Future<void> _identify(File photo, {QueuedCapture? queued}) async {
    unawaited(_cam?.pausePreview());
    setState(() {
      _stage = _Stage.reading;
      _shot = photo;
      _lastShot = photo;
      _progress = 0;
      _error = null;
    });
    final hint = queued == null ? _mode.hint : queued.hint;
    try {
      final result = await ref
          .read(captureApiProvider)
          .identify(photo, hint: hint, onProgress: (v) => mounted ? setState(() => _progress = v) : null);
      if (queued != null) await ref.read(captureQueueProvider.notifier).remove(queued.id);
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _stage = _Stage.review;
        _result = result;
      });
    } on Object catch (e) {
      final error = ApiError.from(e, 'Could not read this photo.');
      if (!mounted) return;
      if (error.isOffline && queued == null) {
        final saved = await ref.read(captureQueueProvider.notifier).add(photo, hint: hint);
        if (!mounted) return;
        showNxToast(
          context,
          saved
              ? 'You’re offline — photo saved. Read it from the queue when you’re back.'
              : 'You’re offline and the queue is full.',
          error: !saved,
        );
        _retake();
      } else {
        setState(() {
          _stage = _Stage.failed;
          _error = error;
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _stage = _Stage.aim;
      _shot = null;
      _result = null;
      _error = null;
    });
    if (_cam == null && !_isBarcode) {
      unawaited(_initCamera());
    } else {
      unawaited(_cam?.resumePreview());
    }
  }

  /// Label reading failed: fall back to the regular add forms, keeping the photo.
  Future<void> _addByHand() async {
    final kind = switch (_mode) {
      CaptureMode.wine => 'wine',
      CaptureMode.beer => 'beer',
      CaptureMode.spirit => 'spirit',
      CaptureMode.book => 'book',
      _ => await showNxSheet<String>(
        context,
        title: 'What is it?',
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, label, icon) in [
              ('wine', 'A wine', LucideIcons.wine),
              ('beer', 'A beer', LucideIcons.beer),
              ('spirit', 'A spirit', LucideIcons.martini),
              ('book', 'A book', LucideIcons.bookOpen),
            ])
              NxListRow(label: label, icon: icon, onTap: () => Navigator.of(sheet).pop(k)),
          ],
        ),
      ),
    };
    if (kind == null || !mounted) return;
    if (kind == 'book') {
      final book = await showAddBookSheet(context);
      if (book?.integer('id') case final id? when mounted) context.go('/library/books/$id');
      return;
    }
    final drink = DrinkKind.values.firstWhere((k) => k.noun == kind);
    final created = await showDrinkCreateSheet(context, drink);
    final id = created?.integer('id');
    if (id == null || !mounted) return;
    if (_shot case final shot?) {
      try {
        await ref
            .read(mediaUploaderProvider)
            .upload(shot, collection: drink.uploadCollection, attachType: drink.attachType, attachId: id);
        ref.read(drinksApiProvider).imageAttached(drink, id);
      } on Object {
        // The record exists; the photo can be added from its page.
      }
    }
    if (mounted) context.go(drink.pathFor(id));
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_scanBusy) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    final isbn = isbnFromBarcode(raw);
    if (isbn == null) {
      _scanNoteTimer?.cancel();
      setState(() => _scanNote = 'That’s not a book barcode');
      _scanNoteTimer = Timer(const Duration(seconds: 2), () => mounted ? setState(() => _scanNote = null) : null);
      return;
    }
    _scanBusy = true;
    unawaited(HapticFeedback.mediumImpact());
    await _scanner?.stop();
    if (!mounted) return;
    final book = await showAddBookSheet(context, initialQuery: isbn);
    if (!mounted) return;
    if (book?.integer('id') case final id?) {
      context.go('/library/books/$id');
      return;
    }
    _scanBusy = false;
    await _scanner?.start();
  }

  Future<void> _showQueue() => showNxSheet<void>(
    context,
    title: 'Waiting to be read',
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final c = context.nx;
        final items = ref.watch(captureQueueProvider).value ?? const [];
        final online = ref.watch(onlineProvider).value ?? true;
        if (items.isEmpty) {
          return const NxEmptyState(compact: true, title: 'All caught up', body: 'No photos are waiting.');
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                online ? 'You’re back online — read them now.' : 'Still offline. These read once you reconnect.',
                style: NxText.muted(context),
              ),
            ),
            for (final q in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(NxRadius.sm),
                      child: Image.file(q.file, width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 156),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CaptureMode.from(q.hint).label,
                            style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                          ),
                          Text(relativeTime(q.at), style: NxText.muted(context, size: 12.5)),
                        ],
                      ),
                    ),
                    NxButton(
                      'Read',
                      compact: true,
                      onPressed: online
                          ? () {
                              Navigator.of(sheet).pop();
                              unawaited(_identify(q.file, queued: q));
                            }
                          : null,
                    ),
                    NxIconButton(
                      LucideIcons.trash2,
                      tooltip: 'Discard photo',
                      size: 36,
                      onPressed: () => ref.read(captureQueueProvider.notifier).remove(q.id),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final queued = ref.watch(captureQueueProvider).value?.length ?? 0;
    final aiming = _stage == _Stage.aim;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _night,
        resizeToAvoidBottomInset: _stage == _Stage.review,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _viewfinder(),
            const _Scrims(),
            if (_isBarcode && aiming)
              _ScanFrame(note: _scanNote)
            else if (_stage != _Stage.review)
              Center(child: _Brackets(locked: _stage == _Stage.reading)),
            if (_stage != _Stage.review)
              Positioned(
                left: 0,
                right: 0,
                top: size.height * .5 + 120,
                child: Center(
                  child: _GlassChip(
                    busy: _stage == _Stage.reading,
                    label: switch (_stage) {
                      _Stage.reading => _progress > 0 && _progress < 1 ? 'Uploading…' : 'Reading the label…',
                      _Stage.failed => 'Couldn’t read it',
                      _ => _isBarcode ? (_scanNote ?? _mode.aim) : _mode.aim,
                    },
                  ),
                ),
              ),
            if (aiming) ...[
              Positioned(left: 24, right: 24, bottom: pad.bottom + 150, child: _Caption(_mode.caption)),
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + 40,
                child: _Controls(
                  lastShot: _lastShot,
                  queued: queued,
                  onQueue: queued > 0 ? _showQueue : null,
                  onShutter: _isBarcode || _cam == null ? null : _shoot,
                  onLibrary: _isBarcode ? null : _pickFromLibrary,
                ),
              ),
            ],
            if (_stage == _Stage.failed)
              Positioned(
                left: 16,
                right: 16,
                bottom: pad.bottom + 28,
                child: _FailedPanel(
                  message: _error?.message ?? 'Could not read this photo.',
                  retryAfter: _error?.retryAfter,
                  onRetry: _shot == null ? null : () => _identify(_shot!),
                  onRetake: _retake,
                  onManual: _addByHand,
                ),
              ),
            if (_stage == _Stage.review && _result != null)
              Positioned(
                left: 0,
                right: 0,
                top: size.height * .28,
                bottom: 0,
                child: CaptureReview(result: _result!, onRetake: _retake),
              ),
            Positioned(
              left: 14,
              right: 14,
              top: pad.top + 10,
              child: Row(
                children: [
                  _GlassIcon(LucideIcons.x, tooltip: 'Close', onTap: _close),
                  const SizedBox(width: 8),
                  Expanded(
                    child: aiming
                        ? Center(
                            child: _ModePills(value: _mode, onChanged: _setMode),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  if (aiming && (_cam != null || _scanner != null))
                    _GlassIcon(
                      _torch ? LucideIcons.zapOff : LucideIcons.zap,
                      tooltip: _torch ? 'Torch off' : 'Torch on',
                      onTap: _toggleTorch,
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _flash ? .9 : 0,
                duration: Duration(milliseconds: _flash ? 40 : 420),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewfinder() {
    if (_shot case final shot? when _stage != _Stage.aim) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(shot, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x380E0608)),
        ],
      );
    }
    if (_isBarcode) {
      final scanner = _scanner;
      if (scanner == null) return const SizedBox.shrink();
      return MobileScanner(
        controller: scanner,
        onDetect: _onBarcode,
        errorBuilder: (_, _) => _CameraFallback(
          message: 'The scanner needs camera access. Allow it in Settings.',
          onPick: () => _setMode(CaptureMode.book),
          pickLabel: 'Photograph the cover instead',
        ),
      );
    }
    final cam = _cam;
    if (cam != null && cam.value.isInitialized) {
      final preview = cam.value.previewSize;
      return ClipRect(
        child: preview == null
            ? CameraPreview(cam)
            : FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: preview.height, height: preview.width, child: CameraPreview(cam)),
              ),
      );
    }
    if (_camError case final message?) {
      return _CameraFallback(message: message, onPick: _pickFromLibrary, pickLabel: 'Choose a photo');
    }
    return const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)));
  }
}

class _Scrims extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xA80E0608), Color(0x000E0608)],
              ),
            ),
          ),
        ),
        Spacer(),
        SizedBox(
          height: 330,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000E0608), Color(0xCC0E0608)],
                stops: [0, .6],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Glass extends StatelessWidget {
  const new({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(NxRadius.pill),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(color: _glass, padding: padding, child: child),
    ),
  );
}

class _GlassIcon extends StatelessWidget {
  const new(this.icon, {required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: _Glass(
          child: SizedBox.square(dimension: 44, child: Icon(icon, size: 20, color: Colors.white)),
        ),
      ),
    ),
  );
}

class _ModePills extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final CaptureMode value;
  final ValueChanged<CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) => _Glass(
    padding: const EdgeInsets.all(4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in CaptureMode.values)
            Semantics(
              button: true,
              selected: m == value,
              child: GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onChanged(m);
                },
                child: AnimatedContainer(
                  duration: NxMotion.hover,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: m == value ? _blush : Colors.transparent,
                    borderRadius: BorderRadius.circular(NxRadius.pill),
                  ),
                  child: Text(
                    m.label,
                    style: NxText.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: m == value ? const Color(0xFF1A090D) : Colors.white.withValues(alpha: .72),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  const new({required this.label, this.busy = false});

  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) => _Glass(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const NxLiveDot(color: _rose, size: 7)
        else
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Color(0xFF5ECF8A), shape: BoxShape.circle),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: NxText.sans(size: 13, weight: FontWeight.w500, color: Colors.white),
        ),
      ],
    ),
  );
}

class _Caption extends StatelessWidget {
  const new(this.caption);

  final (String, String, String) caption;

  @override
  Widget build(BuildContext context) {
    final (before, em, after) = caption;
    final style = NxText.serif(size: 24, color: Colors.white, height: 1.1);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: em,
            style: style.copyWith(color: _rose, fontStyle: FontStyle.italic),
          ),
          TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _Controls extends StatelessWidget {
  const new({
    required this.lastShot,
    required this.queued,
    required this.onQueue,
    required this.onShutter,
    required this.onLibrary,
  });

  final File? lastShot;
  final int queued;
  final VoidCallback? onQueue;
  final VoidCallback? onShutter;
  final VoidCallback? onLibrary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          button: onQueue != null,
          label: queued > 0 ? '${plural(queued, 'photo')} waiting to be read' : 'Last photo',
          child: GestureDetector(
            onTap: onQueue,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _glass,
                    borderRadius: BorderRadius.circular(NxRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2),
                  ),
                  child: lastShot == null
                      ? Icon(LucideIcons.clock, size: 18, color: Colors.white.withValues(alpha: queued > 0 ? 1 : .4))
                      : Image.file(lastShot!, fit: BoxFit.cover, cacheWidth: 150),
                ),
                if (queued > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _rose, borderRadius: BorderRadius.circular(NxRadius.pill)),
                      child: Text(
                        '$queued',
                        style: NxText.sans(size: 11, weight: FontWeight.w700, color: const Color(0xFF1A090D)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          enabled: onShutter != null,
          label: 'Take photo',
          child: GestureDetector(
            onTap: onShutter,
            child: AnimatedOpacity(
              duration: NxMotion.hover,
              opacity: onShutter == null ? .35 : 1,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
        Opacity(
          opacity: onLibrary == null ? .35 : 1,
          child: _GlassIcon(LucideIcons.image, tooltip: 'Choose from library', onTap: onLibrary ?? () {}),
        ),
      ],
    ),
  );
}

/// Corner brackets that breathe while aiming and lock (rose) while reading.
class _Brackets extends StatefulWidget {
  const new({required this.locked});

  final bool locked;

  @override
  State<_Brackets> createState() => _BracketsState();
}

class _BracketsState extends State<_Brackets> with SingleTickerProviderStateMixin {
  late final _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final box = AnimatedContainer(
      duration: NxMotion.enter,
      curve: NxMotion.ease,
      width: widget.locked ? 190 : 210,
      height: widget.locked ? 250 : 270,
      child: CustomPaint(painter: _BracketPainter(widget.locked ? _rose : Colors.white)),
    );
    if (widget.locked || reduce) return IgnorePointer(child: box);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (_, child) => Opacity(
          opacity: 1 - _breathe.value * .25,
          child: Transform.scale(scale: 1 - _breathe.value * .06, child: child),
        ),
        child: box,
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 30.0;
    const r = 10.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final (w, h) = (size.width, size.height);
    final corners = [
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(arm, 0),
      Path()
        ..moveTo(w - arm, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, arm),
      Path()
        ..moveTo(w, h - arm)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
        ..lineTo(w - arm, h),
      Path()
        ..moveTo(arm, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
        ..lineTo(0, h - arm),
    ];
    for (final p in corners) {
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

/// Barcode window: dims everything outside, with a sweeping accent line.
class _ScanFrame extends StatefulWidget {
  const new({this.note});

  final String? note;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const frame = Size(266, 178);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _DimOutside(frame)),
          Center(
            child: SizedBox.fromSize(
              size: frame,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NxRadius.xxl),
                      border: Border.all(color: widget.note == null ? Colors.white : _rose, width: 2),
                    ),
                  ),
                  if (!reduce)
                    AnimatedBuilder(
                      animation: _sweep,
                      builder: (_, _) => Positioned(
                        left: 14,
                        right: 14,
                        top: 20 + _sweep.value * (frame.height - 42),
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            color: _rose,
                            boxShadow: [BoxShadow(color: _rose, blurRadius: 14)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimOutside extends CustomPainter {
  const new(this.frame);

  final Size frame;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: frame.width, height: frame.height),
      const Radius.circular(NxRadius.xxl),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = const Color(0x59000000),
    );
  }

  @override
  bool shouldRepaint(_DimOutside old) => old.frame != frame;
}

class _CameraFallback extends StatelessWidget {
  const new({required this.message, required this.onPick, required this.pickLabel});

  final String message;
  final VoidCallback onPick;
  final String pickLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cameraOff, size: 32, color: Colors.white.withValues(alpha: .7)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: NxText.sans(size: 15, color: Colors.white.withValues(alpha: .85)),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onPick,
            child: _Glass(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                pickLabel,
                style: NxText.sans(weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FailedPanel extends StatelessWidget {
  const new({
    required this.message,
    required this.onRetry,
    required this.onRetake,
    required this.onManual,
    this.retryAfter,
  });

  final String message;
  final int? retryAfter;
  final VoidCallback? onRetry;
  final VoidCallback onRetake;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.amb, borderRadius: BorderRadius.circular(NxRadius.xxl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Couldn’t read the label', style: NxText.serif(size: 26, color: c.ink)),
          const SizedBox(height: 6),
          Text(retryAfter == null ? message : '$message (about ${retryAfter}s)', style: NxText.sans(color: c.ink2)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NxButton('Try again', icon: LucideIcons.refreshCw, onPressed: onRetry),
              NxButton('Add by hand', variant: NxButtonVariant.secondary, onPressed: onManual),
              NxButton('Retake', variant: NxButtonVariant.ghost, onPressed: onRetake),
            ],
          ),
        ],
      ),
    );
  }
}
