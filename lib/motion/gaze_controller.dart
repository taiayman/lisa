import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'gaze_source.dart';

class GazeController extends ChangeNotifier {
  GazeController(this.source) {
    _sub = source.gaze.listen((g) => _target = g);
    _ticker = Ticker(_tick)..start();
  }

  final GazeSource source;
  StreamSubscription<Offset>? _sub;
  late final Ticker _ticker;
  Offset _target = Offset.zero;

  static const _alpha = 0.18; // smoothing per frame

  double gazeX = 0;
  double gazeY = 0;

  void _tick(Duration _) {
    final dx = (_target.dx - gazeX) * _alpha;
    final dy = (_target.dy - gazeY) * _alpha;
    if (dx.abs() < 1e-4 && dy.abs() < 1e-4) return;
    gazeX += (_target.dx - gazeX) * _alpha;
    gazeY += (_target.dy - gazeY) * _alpha;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    source.dispose();
    super.dispose();
  }
}
