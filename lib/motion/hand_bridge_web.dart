import 'dart:js_interop';
import 'dart:typed_data';

// see web/hand.js
@JS('lisaHand.start')
external JSPromise<JSAny?> _start();
@JS('lisaHand.lm')
external JSFloat32Array? get _lm;
@JS('lisaHand.age')
external double _age();
@JS('lisaHand.status')
external String get _status;

Future<void> start() => _start().toDart;

/// 21 normalised (x, y) pairs from the camera frame, or null.
Float32List? get landmarks => _lm?.toDart;
double get ageMs => _age();
String get status => _status;
void dispose() {}
