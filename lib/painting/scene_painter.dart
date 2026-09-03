import 'package:flutter/rendering.dart';

import '../motion/pose.dart';
import 'eyes_painter.dart';
import 'face_mesh.dart';
import 'geometry.dart';

class ScenePainter extends CustomPainter {
  ScenePainter({required this.mesh, this.pose = const Pose()});

  final FaceMesh mesh;
  final Pose pose;

  @override
  void paint(Canvas canvas, Size size) {
    mesh.update(pose);
    final s = scaleFor(size);
    canvas.save();
    canvas.translate(offsetFor(size).dx, offsetFor(size).dy);
    canvas.scale(s);
    mesh.draw(canvas);
    EyesPainter(pose: pose, warp: mesh.warp).paintImage(canvas, size);
    _signature(canvas, size, s);
    canvas.restore();
  }

  // tiny, bottom right
  void _signature(Canvas canvas, Size size, double s) {
    final off = offsetFor(size);
    final anchor = Offset(
      (size.width - off.dx) / s - 150,
      (size.height - off.dy) / s - 190,
    );
    final ink = Paint()
      ..color = const Color(0xD9b08a44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(-0.06);
    canvas.translate(-46, 2);
    final mono = Path()
      ..moveTo(0, 8)
      ..cubicTo(4, -6, 8, -14, 10, -10)
      ..cubicTo(12, -6, 12, 4, 14, 8)
      ..moveTo(3, 2)
      ..cubicTo(8, 0, 14, -2, 22, -3)
      ..moveTo(19, -8)
      ..cubicTo(19, 0, 19, 6, 21, 9)
      ..cubicTo(22, 11, 25, 9, 26, 6);
    canvas.drawPath(mono, ink);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'ayman tai',
        style: TextStyle(
          color: Color(0xD9b08a44),
          fontSize: 7,
          fontStyle: FontStyle.italic,
          fontFamily: 'serif',
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(30, -8));
    final swash = Path()
      ..moveTo(28, 4)
      ..cubicTo(45, 8, 60, 0, 30 + tp.width + 6, 3)
      ..cubicTo(68, 5, 62, 8, 58, 6);
    canvas.drawPath(swash, ink..strokeWidth = 0.8);
    final year = TextPainter(
      text: const TextSpan(
        text: 'MMXXVI · written in code',
        style: TextStyle(
          color: Color(0xA6b08a44),
          fontSize: 3.6,
          fontFamily: 'serif',
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    year.paint(canvas, const Offset(31, 7));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.mesh != mesh || old.pose != pose;
}
