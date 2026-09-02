import 'dart:ui';

const double imgW = 1611;
const double imgH = 2560;

double scaleFor(Size size) => size.width / imgW > size.height / imgH
    ? size.width / imgW
    : size.height / imgH;

Offset offsetFor(Size size) {
  final s = scaleFor(size);
  return Offset((size.width - imgW * s) / 2, (size.height - imgH * s) / 2);
}

Path polygon(List<Offset> pts) => Path()..addPolygon(pts, true);
