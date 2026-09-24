// lib/widgets/dashed_divider.dart
//
// Divisor punteado tipo borde de recibo, usado en Pagos.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(color ?? ConviveColors.paperMuted.withValues(alpha: 0.35)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => oldDelegate.color != color;
}
