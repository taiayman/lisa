import 'dart:async';
import 'dart:ui';

import 'gaze_source.dart';

class PointerGazeSource extends GazeSource {
  final _ctrl = StreamController<Offset>.broadcast();

  @override
  Stream<Offset> get gaze => _ctrl.stream;

  void update(Offset position, Size screen) {
    _ctrl.add(
      Offset(
        (position.dx / screen.width * 2 - 1).clamp(-1, 1),
        (position.dy / screen.height * 2 - 1).clamp(-1, 1),
      ),
    );
  }

  @override
  void dispose() => _ctrl.close();
}
