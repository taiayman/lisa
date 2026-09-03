import 'dart:async';
import 'dart:ui';

import 'package:sensors_plus/sensors_plus.dart';

abstract class GazeSource {
  Stream<Offset> get gaze;

  /// 0..1, asks the eyes to close (closed fist on the hand source).
  double get shut => 0;
  void dispose() {}
}

class TiltGazeSource extends GazeSource {
  TiltGazeSource() {
    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen(_onEvent);
  }

  static const _range = 4.0; // m/s^2 of tilt for a full gaze

  final _ctrl = StreamController<Offset>.broadcast();
  StreamSubscription? _sub;
  Offset? _neutral;

  @override
  Stream<Offset> get gaze => _ctrl.stream;

  void recenter() => _neutral = null;

  void _onEvent(AccelerometerEvent e) {
    final v = Offset(e.x, e.z);
    _neutral ??= v;
    final d = v - _neutral!;
    _ctrl.add(
      Offset((-d.dx / _range).clamp(-1, 1), (d.dy / _range).clamp(-1, 1)),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}
