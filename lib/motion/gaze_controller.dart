import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'gaze_source.dart';
import 'pose.dart';

class GazeController extends ChangeNotifier {
  GazeController(this.source) {
    _sub = source.gaze.listen(_onTarget);
    _ticker = Ticker(_tick)..start();
  }

  final GazeSource source;
  StreamSubscription<Offset>? _sub;
  late final Ticker _ticker;
  final _rnd = math.Random();

  Offset _target = Offset.zero;
  double _targetChangedAt = 0;
  double _t = 0;

  // eyes: underdamped spring, small overshoot
  static const _omega = 18.0;
  static const _zeta = 0.72;
  double _ex = 0, _ey = 0, _vx = 0, _vy = 0;

  // head: first order lag
  static const _headTau = 0.35;
  double _hx = 0, _hy = 0;

  double _blinkStart = -1;
  double _nextBlink = 3;
  double _nextSaccade = 0;
  Offset _saccade = Offset.zero;
  double _dil = 0;
  double _shut = 0;

  Pose pose = const Pose();
  double get gazeX => pose.gazeX;
  double get gazeY => pose.gazeY;

  void _onTarget(Offset g) {
    if ((g - _target).distance < 1e-3) return;
    _target = g;
    _targetChangedAt = _t;
    _saccade = Offset.zero;
  }

  static double _smooth(double x) {
    x = x.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _t).clamp(0.0, 0.05);
    _t = now;

    // micro drift + occasional micro saccade while the target is still
    final idle = now - _targetChangedAt > 0.6;
    if (!idle) {
      _nextSaccade = now + 1.0;
    } else if (now >= _nextSaccade) {
      _saccade = Offset(
        (_rnd.nextDouble() - .5) * .06,
        (_rnd.nextDouble() - .5) * .04,
      );
      _nextSaccade = now + 1.2 + _rnd.nextDouble() * 2;
    }
    final tx =
        _target.dx +
        _saccade.dx +
        0.012 * math.sin(1.1 * now) +
        0.008 * math.sin(2.3 * now + 1);
    final ty =
        _target.dy +
        _saccade.dy +
        0.010 * math.cos(0.9 * now) +
        0.006 * math.sin(1.7 * now);

    _vx += (_omega * _omega * (tx - _ex) - 2 * _zeta * _omega * _vx) * dt;
    _vy += (_omega * _omega * (ty - _ey) - 2 * _zeta * _omega * _vy) * dt;
    _ex += _vx * dt;
    _ey += _vy * dt;

    final k = 1 - math.exp(-dt / _headTau);
    _hx += (_target.dx - _hx) * k;
    _hy += (_target.dy - _hy) * k;

    // blink: 120ms down, 160ms up, every 4..7s
    var blink = 0.0;
    if (_blinkStart < 0 && now >= _nextBlink) _blinkStart = now;
    if (_blinkStart >= 0) {
      final u = now - _blinkStart;
      if (u < .12) {
        blink = _smooth(u / .12);
      } else if (u < .28) {
        blink = 1 - _smooth((u - .12) / .16);
      } else {
        _blinkStart = -1;
        _nextBlink = now + 4 + _rnd.nextDouble() * 3;
      }
    }

    // closed fist: eyes shut, fast lag
    _shut += (source.shut - _shut) * (1 - math.exp(-dt / .12));
    blink = math.max(blink, _shut);

    final near = _target.distance < 0.25 ? 1.0 : 0.0;
    _dil += (near - _dil).clamp(-dt / .4, dt / .4);

    pose = Pose(
      gazeX: _ex,
      gazeY: _ey,
      headX: _hx,
      headY: _hy,
      blink: blink,
      dilation: _dil,
    );
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
