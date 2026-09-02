import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion/gaze_controller.dart';
import 'motion/pointer_gaze_source.dart';
import 'painting/scene_painter.dart';

class MonaLisaScreen extends StatefulWidget {
  const MonaLisaScreen({super.key});

  @override
  State<MonaLisaScreen> createState() => _MonaLisaScreenState();
}

class _MonaLisaScreenState extends State<MonaLisaScreen> {
  final _source = PointerGazeSource();
  late final _gaze = GazeController(_source);
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await rootBundle.load('assets/mona.jpg');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _gaze.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: image == null
            ? const SizedBox.shrink()
            : MouseRegion(
                onHover: (e) =>
                    _source.update(e.position, MediaQuery.sizeOf(context)),
                child: Listener(
                  onPointerHover: (e) =>
                      _source.update(e.position, MediaQuery.sizeOf(context)),
                  onPointerDown: (e) =>
                      _source.update(e.position, MediaQuery.sizeOf(context)),
                  onPointerMove: (e) =>
                      _source.update(e.position, MediaQuery.sizeOf(context)),
                  child: ListenableBuilder(
                    listenable: _gaze,
                    builder: (_, _) => CustomPaint(
                      painter: ScenePainter(
                        image: image,
                        gazeX: _gaze.gazeX,
                        gazeY: _gaze.gazeY,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
