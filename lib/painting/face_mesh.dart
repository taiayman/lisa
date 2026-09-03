import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../motion/pose.dart';
import 'eyes_painter.dart';
import 'geometry.dart';

/// Warps the portrait with a coarse mesh over the whole image plus a fine
/// patch over each eye. The same [FaceWarp] is applied to the eye holes so
/// the painted irises stay glued to the skin.
class FaceMesh {
  FaceMesh._(this.image)
    : _shader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: ui.FilterQuality.medium,
      );

  /// Fills the white eye holes with the base ochre first, so the rows that
  /// get squashed under a closed lid read as skin instead of a white line.
  static Future<FaceMesh> create(ui.Image raw) async {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawImage(raw, ui.Offset.zero, ui.Paint());
    // the traced outline sits a few px inside the white, so also stroke it
    for (final paint in [
      ui.Paint()..color = EyesPainter.eyeBackground,
      ui.Paint()
        ..color = EyesPainter.eyeBackground
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4,
    ]) {
      c.drawPath(polygon(EyesPainter.leftHole), paint);
      c.drawPath(polygon(EyesPainter.rightHole), paint);
    }
    final image = await rec.endRecording().toImage(raw.width, raw.height);
    raw.dispose();
    return FaceMesh._(image);
  }

  final ui.Image image;
  final ui.ImageShader _shader;

  final _grids = [
    _Grid(const ui.Rect.fromLTWH(0, 0, imgW, imgH), 40),
    _Grid(_patch(EyesPainter.leftHole), 5),
    _Grid(_patch(EyesPainter.rightHole), 5),
  ];

  static ui.Rect _patch(List<ui.Offset> hole) {
    final r = polygon(hole).getBounds();
    return ui.Rect.fromLTRB(
      r.left - 25,
      r.top - 100,
      r.right + 25,
      r.bottom + 75,
    );
  }

  FaceWarp warp = FaceWarp(const Pose());

  void update(Pose pose) {
    warp = FaceWarp(pose);
    for (final g in _grids) {
      g.update(warp);
    }
  }

  /// Canvas must already be in image space (see ScenePainter).
  void draw(ui.Canvas canvas) {
    final paint = ui.Paint()..shader = _shader;
    for (final g in _grids) {
      canvas.drawVertices(g.vertices, ui.BlendMode.srcOver, paint);
    }
  }

  void dispose() => _shader.dispose();
}

class _Grid {
  _Grid(this.rect, double spacing)
    : cols = (rect.width / spacing).ceil() + 1,
      rows = (rect.height / spacing).ceil() + 1 {
    final n = cols * rows;
    uv = Float32List(n * 2);
    pos = Float32List(n * 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = (r * cols + c) * 2;
        uv[i] = rect.left + rect.width * c / (cols - 1);
        uv[i + 1] = rect.top + rect.height * r / (rows - 1);
      }
    }
    index = Uint16List((cols - 1) * (rows - 1) * 6);
    var k = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c;
        index[k++] = a;
        index[k++] = a + 1;
        index[k++] = a + cols;
        index[k++] = a + 1;
        index[k++] = a + cols + 1;
        index[k++] = a + cols;
      }
    }
    pos.setAll(0, uv);
    vertices = _build();
  }

  final ui.Rect rect;
  final int cols, rows;
  late final Float32List uv, pos;
  late final Uint16List index;
  late ui.Vertices vertices;

  void update(FaceWarp w) {
    for (var i = 0; i < uv.length; i += 2) {
      w.warpInto(pos, i, uv[i], uv[i + 1]);
    }
    vertices = _build();
  }

  ui.Vertices _build() => ui.Vertices.raw(
    ui.VertexMode.triangles,
    pos,
    textureCoordinates: uv,
    indices: index,
  );
}

/// Displacement field in image pixels: head roll around the neck, a small
/// feature shift for parallax, eyelids following the gaze and the blink.
class FaceWarp {
  FaceWarp(this.pose)
    : _cos = math.cos(_maxRoll * pose.headX),
      _sin = math.sin(_maxRoll * pose.headX),
      _lids = [_LidState(_leftLid, pose), _LidState(_rightLid, pose)];

  final Pose pose;
  final double _cos, _sin;
  final List<_LidState> _lids;

  static const _maxRoll = 2 * math.pi / 180;
  static const _pivot = ui.Offset(700, 1300);
  static final _leftLid = _Lid(EyesPainter.leftHole);
  static final _rightLid = _Lid(EyesPainter.rightHole);

  // 1 inside, smooth to 0 over the outer [fade] fraction of the ellipse
  static double _ellipse(
    double x,
    double y,
    double cx,
    double cy,
    double rx,
    double ry,
    double fade,
  ) {
    final dx = (x - cx) / rx, dy = (y - cy) / ry;
    final r = math.sqrt(dx * dx + dy * dy);
    final t = ((1 - r) / fade).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  ui.Offset apply(ui.Offset p) {
    final out = Float32List(2);
    warpInto(out, 0, p.dx, p.dy);
    return ui.Offset(out[0], out[1]);
  }

  void warpInto(Float32List out, int i, double x, double y) {
    var dx = 0.0, dy = 0.0;
    final head = _ellipse(x, y, 700, 720, 480, 640, .35);
    if (head > 0) {
      final px = x - _pivot.dx, py = y - _pivot.dy;
      dx += (_cos * px - _sin * py - px) * head;
      dy += (_sin * px + _cos * py - py) * head;
      final face = _ellipse(x, y, 668, 780, 260, 330, .5);
      dx += 7 * pose.headX * face;
      dy += 3 * pose.headY * face;
      for (final l in _lids) {
        dy += l.dy(x, y);
      }
    }
    out[i] = x + dx;
    out[i + 1] = y + dy;
  }
}

/// Top and bottom edge of an eye hole, sampled per pixel column.
class _Lid {
  _Lid(List<ui.Offset> hole) {
    var imax = 0;
    for (var i = 1; i < hole.length; i++) {
      if (hole[i].dx > hole[imax].dx) imax = i;
    }
    x0 = hole[0].dx.floor();
    final x1 = hole[imax].dx.ceil();
    cx = (x0 + x1) / 2;
    halfW = (x1 - x0) / 2;
    top = _sample(hole.sublist(0, imax + 1), x0, x1);
    bot = _sample([hole[0], ...hole.sublist(imax).reversed], x0, x1);
  }

  late final int x0;
  late final double cx, halfW;
  late final Float64List top, bot;

  // chain must be sorted by x ascending
  static Float64List _sample(List<ui.Offset> chain, int x0, int x1) {
    final out = Float64List(x1 - x0 + 1);
    for (var x = x0; x <= x1; x++) {
      var j = 0;
      while (j < chain.length - 2 && chain[j + 1].dx < x) {
        j++;
      }
      final a = chain[j], b = chain[j + 1];
      final t = ((x - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
      out[x - x0] = a.dy + (b.dy - a.dy) * t;
    }
    return out;
  }

  double topAt(double x) => _at(top, x);
  double botAt(double x) => _at(bot, x);
  double _at(Float64List v, double x) {
    final f = (x - x0).clamp(0.0, v.length - 1.0);
    final i = f.floor();
    final t = f - i;
    return i + 1 < v.length ? v[i] + (v[i + 1] - v[i]) * t : v[i];
  }
}

class _LidState {
  _LidState(this.lid, Pose pose)
    : upper = pose.gazeY < 0 ? 5 * pose.gazeY : 8 * pose.gazeY,
      lower = (pose.gazeY > 0 ? 4 * pose.gazeY : 0) + 5 * pose.blink,
      blink = pose.blink;

  final _Lid lid;
  final double upper; // px, + lowers the upper lid
  final double lower; // px, + raises the lower lid
  final double blink;

  static const _above = 55.0; // skin band that stretches above the lid
  static const _below = 40.0;

  double dy(double x, double y) {
    final u = (x - lid.cx) / lid.halfW;
    if (u <= -1 || u >= 1) return 0;
    final topY = lid.topAt(x), botY = lid.botAt(x);
    if (y < topY - _above || y > botY + _below) return 0;
    final m = 1 - u * u;
    final h = botY - topY;
    final b = lower * m;
    // a + b <= h so the lids meet instead of crossing when closed
    final a = math.min(upper * m + blink * (h - b), h - b);
    double wu, wl;
    if (y < topY) {
      final t = 1 - (topY - y) / _above;
      wu = t * t * (3 - 2 * t);
      wl = 0;
    } else if (y > botY) {
      final t = 1 - (y - botY) / _below;
      wl = t * t * (3 - 2 * t);
      wu = 0;
    } else if (h < 0.5) {
      wu = wl = 0.5;
    } else {
      wl = (y - topY) / h;
      wu = 1 - wl;
    }
    return a * wu - b * wl;
  }
}
