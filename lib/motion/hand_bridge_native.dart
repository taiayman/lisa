import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

// Android: front camera frames → MediaPipe Hand Landmarker (JNI plugin).
// Same surface as hand_bridge_web.dart.
CameraController? _camera;
HandLandmarkerPlugin? _plugin;
StreamSubscription<List<Hand>>? _sub;
Float32List? _lm;
int _seen = -1 << 40;
String status = 'loading model…';

Future<void> start() async {
  if (!Platform.isAndroid) {
    status = 'hand tracking: web and Android only';
    throw UnsupportedError(status);
  }
  try {
    final cams = await availableCameras();
    if (cams.isEmpty) throw StateError('no camera');
    final cam = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    status = 'waiting for camera permission…';
    _camera = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _camera!.initialize();
    _plugin = HandLandmarkerPlugin.create(numHands: 1);
    _sub = _plugin!.landmarkStream.listen((hands) {
      if (hands.isEmpty) {
        _lm = null;
        status = 'no hand';
        return;
      }
      // frames are fed unrotated (MediaPipe mis-projects rotated 4:3 frames),
      // so bring the sensor-frame landmarks upright here
      final out = Float32List(42);
      final pts = hands.first.landmarks;
      for (var i = 0; i < 21; i++) {
        final (x, y) = switch (cam.sensorOrientation) {
          90 => (1 - pts[i].y, pts[i].x),
          180 => (1 - pts[i].x, 1 - pts[i].y),
          270 => (pts[i].y, 1 - pts[i].x),
          _ => (pts[i].x, pts[i].y),
        };
        out[i * 2] = x;
        out[i * 2 + 1] = y;
      }
      _lm = out;
      _seen = DateTime.now().millisecondsSinceEpoch;
      status = 'tracking';
    });
    await _camera!.startImageStream((img) => _plugin?.processFrame(img, 0));
    status = 'no hand';
  } catch (e) {
    status = 'camera unavailable: $e';
    rethrow;
  }
}

Float32List? get landmarks => _lm;
double get ageMs => (DateTime.now().millisecondsSinceEpoch - _seen).toDouble();

void dispose() {
  _sub?.cancel();
  _camera?.dispose();
  _plugin?.dispose();
}
