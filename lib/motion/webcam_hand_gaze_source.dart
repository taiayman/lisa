import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'hand_bridge_native.dart'
    if (dart.library.js_interop) 'hand_bridge_web.dart'
    as hand;
import 'gaze_source.dart';

/// Index fingertip (MediaPipe landmark 8) from the camera, mirrored and
/// low-pass filtered. [tracking] goes false 500ms after the hand is lost.
/// A closed fist sets [shut] so she closes her eyes.
class WebcamHandGazeSource implements GazeSource {
  WebcamHandGazeSource() {
    hand.start().then((_) => _ready = true, onError: (_) {});
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _poll());
  }

  static const _lostAfterMs = 500.0;
  static const _span = 0.3; // fraction of the frame that maps to full gaze
  static const _alpha = 0.35;

  final _ctrl = StreamController<Offset>.broadcast();
  Timer? _timer;
  bool _ready = false;
  Offset _v = Offset.zero;
  double _shut = 0;

  @override
  Stream<Offset> get gaze => _ctrl.stream;

  @override
  double get shut => tracking ? _shut : 0;

  bool get tracking => _ready && hand.ageMs < _lostAfterMs;
  String get status => hand.status;
  Float32List? get landmarks => hand.landmarks;

  void _poll() {
    final lm = hand.landmarks;
    if (!tracking || lm == null) return;
    final raw = Offset(
      ((0.5 - lm[16]) / _span).clamp(-1.0, 1.0), // mirrored
      ((lm[17] - 0.5) / _span).clamp(-1.0, 1.0),
    );
    _v += (raw - _v) * _alpha;
    _shut = fistOf(lm) >= .75 ? 1 : 0;
    _ctrl.add(_v);
  }

  /// Fraction of fingers curled: tip closer to the wrist than its pip joint.
  static double fistOf(Float32List lm) {
    double d(int i) => math.sqrt(
      math.pow(lm[i * 2] - lm[0], 2) + math.pow(lm[i * 2 + 1] - lm[1], 2),
    );
    var curled = 0;
    for (final (tip, pip) in [(8, 6), (12, 10), (16, 14), (20, 18)]) {
      if (d(tip) < d(pip)) curled++;
    }
    return curled / 4;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.close();
    hand.dispose();
  }
}

/// Uses [hand] while it is tracking, otherwise [pointer]. Crossfades over
/// 400ms when switching so the gaze never jumps.
class HandOrPointerGazeSource implements GazeSource {
  HandOrPointerGazeSource(this.hand, this.pointer) {
    _subs = [
      hand.gaze.listen((g) => _handV = g),
      pointer.gaze.listen((g) => _pointerV = g),
    ];
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  final WebcamHandGazeSource hand;
  final GazeSource pointer;
  final _ctrl = StreamController<Offset>.broadcast();
  late final List<StreamSubscription<Offset>> _subs;
  Timer? _timer;
  Offset _handV = Offset.zero, _pointerV = Offset.zero, _out = Offset.zero;
  bool _useHand = false;
  Offset _from = Offset.zero;
  int _switchedAt = 0;

  static const _blendMs = 400;

  @override
  Stream<Offset> get gaze => _ctrl.stream;

  @override
  double get shut => hand.shut;

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (hand.tracking != _useHand) {
      _useHand = hand.tracking;
      _from = _out;
      _switchedAt = now;
    }
    final target = _useHand ? _handV : _pointerV;
    final t = ((now - _switchedAt) / _blendMs).clamp(0.0, 1.0);
    _out = Offset.lerp(_from, target, t * t * (3 - 2 * t))!;
    _ctrl.add(_out);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    hand.dispose();
    pointer.dispose();
    _ctrl.close();
  }
}
