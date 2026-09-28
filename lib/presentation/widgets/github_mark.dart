import 'package:flutter/widgets.dart';

/// GitHub's mark, drawn from the same path the browser extensions use,
/// so the app needs no SVG package for one icon
class GitHubMark extends StatelessWidget {
  final double size;
  final Color color;

  const GitHubMark({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GitHubMarkPainter(color),
    );
  }
}

class _GitHubMarkPainter extends CustomPainter {
  final Color color;

  const _GitHubMarkPainter(this.color);

  /// The mark's path on its 24 by 24 viewBox
  static final Path _mark =
      Path()
        ..moveTo(12, 2)
        ..cubicTo(6.477, 2, 2, 6.484, 2, 12.017)
        ..cubicTo(2, 16.442, 4.865, 20.197, 8.839, 21.521)
        ..cubicTo(9.339, 21.613, 9.521, 21.304, 9.521, 21.038)
        ..cubicTo(9.521, 20.801, 9.513, 20.17, 9.508, 19.335)
        ..cubicTo(6.726, 19.94, 6.139, 17.992, 6.139, 17.992)
        ..cubicTo(5.685, 16.834, 5.029, 16.526, 5.029, 16.526)
        ..cubicTo(4.121, 15.906, 5.098, 15.918, 5.098, 15.918)
        ..cubicTo(6.101, 15.988, 6.629, 16.95, 6.629, 16.95)
        ..cubicTo(7.521, 18.48, 8.97, 18.038, 9.539, 17.782)
        ..cubicTo(9.631, 17.135, 9.889, 16.694, 10.175, 16.444)
        ..cubicTo(7.955, 16.191, 5.62, 15.331, 5.62, 11.493)
        ..cubicTo(5.62, 10.4, 6.01, 9.505, 6.649, 8.805)
        ..cubicTo(6.546, 8.552, 6.203, 7.533, 6.747, 6.155)
        ..cubicTo(6.747, 6.155, 7.587, 5.885, 9.497, 7.181)
        ..arcToPoint(
          const Offset(12, 6.844),
          radius: const Radius.elliptical(9.564, 9.564),
          rotation: 0,
          largeArc: false,
          clockwise: true,
        )
        ..cubicTo(12.85, 6.848, 13.705, 6.959, 14.504, 7.181)
        ..cubicTo(16.413, 5.885, 17.251, 6.154, 17.251, 6.154)
        ..cubicTo(17.797, 7.533, 17.454, 8.552, 17.351, 8.805)
        ..cubicTo(17.991, 9.505, 18.379, 10.4, 18.379, 11.493)
        ..cubicTo(18.379, 15.341, 16.04, 16.188, 13.813, 16.436)
        ..cubicTo(14.172, 16.745, 14.491, 17.355, 14.491, 18.288)
        ..cubicTo(14.491, 19.624, 14.479, 20.703, 14.479, 21.031)
        ..cubicTo(14.479, 21.298, 14.659, 21.609, 15.167, 21.511)
        ..cubicTo(19.138, 20.194, 22, 16.442, 22, 12.017)
        ..cubicTo(22, 6.484, 17.523, 2, 12, 2)
        ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(_mark, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GitHubMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
