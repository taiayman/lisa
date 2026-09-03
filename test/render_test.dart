import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lisa/motion/pose.dart';
import 'package:lisa/painting/face_mesh.dart';
import 'package:lisa/painting/geometry.dart';
import 'package:lisa/painting/scene_painter.dart';

// dumps the scene to a png for eyeballing
// flutter test test/render_test.dart --dart-define=OUT=out.png --dart-define=GAZEX=0.8
void main() {
  test('render scene to png', () async {
    const out = String.fromEnvironment('OUT', defaultValue: 'lisa.png');
    final gazeX = double.parse(
      const String.fromEnvironment('GAZEX', defaultValue: '0'),
    );
    final gazeY = double.parse(
      const String.fromEnvironment('GAZEY', defaultValue: '0'),
    );
    final bytes = File('assets/mona.jpg').readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    const size = Size(imgW, imgH);
    final recorder = ui.PictureRecorder();
    ScenePainter(
      mesh: await FaceMesh.create(image),
      pose: Pose(gazeX: gazeX, gazeY: gazeY, headX: gazeX, headY: gazeY),
    ).paint(Canvas(recorder), size);
    final img = await recorder.endRecording().toImage(
      imgW.toInt(),
      imgH.toInt(),
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
    expect(img.width, imgW.toInt());
  });
}
