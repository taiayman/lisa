import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'eyes_painter.dart';
import 'geometry.dart';

class ScenePainter extends CustomPainter {
  const ScenePainter({
    required this.image,
    required this.gazeX,
    required this.gazeY,
  });

  final ui.Image image;
  final double gazeX;
  final double gazeY;

  static const lensZoom = 2.2;
  static const lensRadiusFrac = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    _portrait(canvas, size);

    final at = Offset(
      (gazeX.clamp(-1, 1) + 1) / 2 * size.width,
      (gazeY.clamp(-1, 1) + 1) / 2 * size.height,
    );
    final r = size.width * lensRadiusFrac;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: r)));
    canvas.translate(at.dx, at.dy);
    canvas.scale(lensZoom);
    canvas.translate(-at.dx, -at.dy);
    _portrait(canvas, size, inLens: true);
    canvas.restore();
  }

  void _portrait(Canvas canvas, Size size, {bool inLens = false}) {
    final s = scaleFor(size);
    canvas.save();
    canvas.translate(offsetFor(size).dx, offsetFor(size).dy);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, imgW * s, imgH * s),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.scale(s);
    EyesPainter(gazeX: gazeX, gazeY: gazeY).paintImage(canvas, size);
    _signature(canvas, size, s, inLens);
    canvas.restore();
  }

  // tiny on the panel, readable through the lens
  void _signature(Canvas canvas, Size size, double s, bool inLens) {
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
    canvas.scale(inLens ? 2.6 : 1);
    canvas.translate(-46, 2);
    if (inLens) {
      canvas.drawOval(
        const Rect.fromLTWH(-14, -22, 96, 44),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
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
  bool shouldRepaint(ScenePainter old) =>
      old.image != image || old.gazeX != gazeX || old.gazeY != gazeY;
}
