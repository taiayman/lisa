import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion/gaze_controller.dart';
import 'motion/pointer_gaze_source.dart';
import 'motion/webcam_hand_gaze_source.dart';
import 'painting/face_mesh.dart';
import 'painting/scene_painter.dart';

class MonaLisaScreen extends StatefulWidget {
  const MonaLisaScreen({super.key});

  @override
  State<MonaLisaScreen> createState() => _MonaLisaScreenState();
}

class _MonaLisaScreenState extends State<MonaLisaScreen> {
  final _pointer = PointerGazeSource();
  final _hand = WebcamHandGazeSource();
  late final _gaze = GazeController(HandOrPointerGazeSource(_hand, _pointer));
  FaceMesh? _mesh;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await rootBundle.load('assets/mona.jpg');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final mesh = await FaceMesh.create(frame.image);
    if (mounted) setState(() => _mesh = mesh);
  }

  @override
  void dispose() {
    _gaze.dispose();
    _mesh?.dispose();
    _mesh?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesh = _mesh;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: mesh == null
            ? const SizedBox.shrink()
            : MouseRegion(
                onHover: (e) =>
                    _pointer.update(e.position, MediaQuery.sizeOf(context)),
                child: Listener(
                  onPointerHover: (e) =>
                      _pointer.update(e.position, MediaQuery.sizeOf(context)),
                  onPointerDown: (e) =>
                      _pointer.update(e.position, MediaQuery.sizeOf(context)),
                  onPointerMove: (e) =>
                      _pointer.update(e.position, MediaQuery.sizeOf(context)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: _gaze,
                          builder: (_, _) => CustomPaint(
                            painter: ScenePainter(mesh: mesh, pose: _gaze.pose),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton(
                          tooltip: 'hand preview',
                          color: Colors.white54,
                          icon: Icon(
                            _preview ? Icons.videocam : Icons.videocam_off,
                          ),
                          onPressed: () => setState(() => _preview = !_preview),
                        ),
                      ),
                      if (_preview)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: ListenableBuilder(
                            listenable: _gaze,
                            builder: (_, _) => HandPreview(
                              landmarks: _hand.landmarks,
                              status: _hand.status,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Small card with the hand skeleton only, never the camera image.
class HandPreview extends StatelessWidget {
  const HandPreview({super.key, required this.landmarks, required this.status});

  final Float32List? landmarks;
  final String status;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 200,
      height: 150,
      color: const Color(0xFF111111),
      child: landmarks == null
          ? Center(
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          : CustomPaint(painter: _SkeletonPainter(landmarks!)),
    ),
  );
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter(this.lm);

  final Float32List lm;

  static const _bones = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (9, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (13, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (0, 17),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(int i) =>
        Offset((1 - lm[i * 2]) * size.width, lm[i * 2 + 1] * size.height);
    final gold = Paint()
      ..color = const Color(0xFFd9ad52)
      ..strokeWidth = 2;
    for (final (a, b) in _bones) {
      canvas.drawLine(p(a), p(b), gold);
    }
    for (var i = 0; i < 21; i++) {
      canvas.drawCircle(
        p(i),
        i == 8 ? 5 : 3,
        i == 8 ? (Paint()..color = Colors.white) : gold,
      );
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => true;
}
