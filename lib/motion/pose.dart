class Pose {
  const Pose({
    this.gazeX = 0,
    this.gazeY = 0,
    this.headX = 0,
    this.headY = 0,
    this.blink = 0,
    this.dilation = 0,
  });

  final double gazeX; // eye direction, -1..1
  final double gazeY;
  final double headX; // slower copy of the gaze, drives the head/face warp
  final double headY;
  final double blink; // 0 open .. 1 closed
  final double dilation; // 0..1
}
