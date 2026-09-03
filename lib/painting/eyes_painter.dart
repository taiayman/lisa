import 'package:flutter/rendering.dart';

import '../motion/pose.dart';
import 'face_mesh.dart';
import 'geometry.dart';

class EyesPainter extends CustomPainter {
  EyesPainter({this.pose = const Pose(), FaceWarp? warp})
    : warp = warp ?? FaceWarp(pose);

  final Pose pose;
  final FaceWarp warp;
  double get gazeX => pose.gazeX;
  double get gazeY => pose.gazeY;

  static const eyeBackground = Color(0xFFd9ad52);
  static const iris = Color(0xFF4e2c14);
  static const irisEdge = Color(0xFF6b3f1c);
  static const pupil = Color(0xFF221207);
  static const varnish = Color(0x26d9ad52);

  // traced from the white pixels in the asset
  static const leftHole = [
    Offset(491, 691),
    Offset(497, 687),
    Offset(503, 684),
    Offset(509, 681),
    Offset(515, 679),
    Offset(521, 677),
    Offset(527, 674),
    Offset(533, 673),
    Offset(539, 672),
    Offset(545, 672),
    Offset(551, 671),
    Offset(557, 672),
    Offset(563, 672),
    Offset(569, 675),
    Offset(575, 679),
    Offset(581, 684),
    Offset(587, 688),
    Offset(588, 690),
    Offset(587, 691),
    Offset(581, 694),
    Offset(575, 700),
    Offset(569, 702),
    Offset(563, 703),
    Offset(557, 704),
    Offset(551, 705),
    Offset(545, 706),
    Offset(539, 706),
    Offset(533, 705),
    Offset(527, 704),
    Offset(521, 703),
    Offset(515, 702),
    Offset(509, 700),
    Offset(503, 697),
    Offset(497, 693),
  ];
  static const rightHole = [
    Offset(723, 695),
    Offset(729, 692),
    Offset(735, 689),
    Offset(741, 686),
    Offset(747, 683),
    Offset(753, 680),
    Offset(759, 678),
    Offset(765, 676),
    Offset(771, 674),
    Offset(777, 673),
    Offset(783, 672),
    Offset(789, 671),
    Offset(795, 670),
    Offset(801, 670),
    Offset(807, 669),
    Offset(813, 669),
    Offset(819, 669),
    Offset(825, 670),
    Offset(831, 672),
    Offset(837, 674),
    Offset(843, 677),
    Offset(849, 680),
    Offset(855, 684),
    Offset(859, 687),
    Offset(859, 688),
    Offset(855, 691),
    Offset(849, 695),
    Offset(843, 698),
    Offset(837, 702),
    Offset(831, 704),
    Offset(825, 706),
    Offset(819, 707),
    Offset(813, 708),
    Offset(807, 708),
    Offset(801, 708),
    Offset(795, 709),
    Offset(789, 708),
    Offset(783, 708),
    Offset(777, 708),
    Offset(771, 707),
    Offset(765, 706),
    Offset(759, 705),
    Offset(753, 704),
    Offset(747, 703),
    Offset(741, 702),
    Offset(735, 700),
    Offset(729, 698),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offsetFor(size).dx, offsetFor(size).dy);
    canvas.scale(scaleFor(size));
    paintImage(canvas, size);
    canvas.restore();
  }

  void paintImage(Canvas canvas, Size size) {
    final screen = Offset(
      (gazeX.clamp(-1, 1) + 1) / 2 * size.width,
      (gazeY.clamp(-1, 1) + 1) / 2 * size.height,
    );
    final target = (screen - offsetFor(size)) / scaleFor(size);
    _eye(canvas, leftHole, const Offset(541, 689), 95, target);
    _eye(canvas, rightHole, const Offset(796, 689), 134, target);
  }

  static const _reach = 500.0;

  void _eye(
    Canvas c,
    List<Offset> hole,
    Offset center,
    double width,
    Offset target,
  ) {
    final path = polygon([for (final p in hole) warp.apply(p)]);
    if (pose.blink > .97) return _crease(c, path); // shut
    c.drawPath(path, Paint()..color = eyeBackground);
    c.save();
    c.clipPath(path);

    final d = target - const Offset(668, 689);
    final k = (d.distance / _reach).clamp(0.0, 1.0) / (d.distance + 1e-6);
    final maxX = width * .28;
    final shift = Offset(
      (d.dx * k * maxX).clamp(-maxX, maxX),
      (d.dy * k * 14).clamp(-12.0, 12.0),
    );
    final ic = warp.apply(center + shift);
    c.drawCircle(
      ic,
      26,
      Paint()
        ..color = irisEdge.withValues(alpha: .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawCircle(
      ic,
      20,
      Paint()
        ..color = iris
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    c.drawCircle(
      ic,
      9 * (1 + .07 * pose.dilation),
      Paint()
        ..color = pupil
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    c.drawCircle(
      ic + const Offset(-6, -6),
      3.5,
      Paint()
        ..color = const Color(0x55f2e0b0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    c.drawPath(path, Paint()..color = varnish);
    c.drawPath(
      path.shift(const Offset(0, -7)),
      Paint()
        ..color = irisEdge.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.restore();
    _crease(c, path);
  }

  void _crease(Canvas c, Path path) => c.drawPath(
    path,
    Paint()
      ..color = const Color(0xB3603a1c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );

  @override
  bool shouldRepaint(EyesPainter old) => old.pose != pose;
}
