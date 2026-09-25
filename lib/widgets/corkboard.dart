// lib/widgets/corkboard.dart
//
// El tablón de notas del piso como un corcho físico: fondo con textura de
// motas (CustomPainter, sin necesitar ningún asset de imagen) sosteniendo
// post-its de colores ligeramente girados.
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class _CorkSpeckles extends CustomPainter {
  const _CorkSpeckles();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7); // semilla fija -- la textura no debe "bailar" al redibujar
    final paint = Paint()..style = PaintingStyle.fill;
    final count = (size.width * size.height / 900).round();
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * 1.1;
      final dark = rnd.nextBool();
      // Vetas del corcho: independientes del tema, es una textura de
      // material, no algo que deba leerse como texto.
      paint.color = (dark ? Colors.black : Colors.white)
          .withValues(alpha: dark ? 0.14 : 0.05);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CorkboardSurface extends StatelessWidget {
  const CorkboardSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.corkDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: const _CorkSpeckles())),
          child,
        ],
      ),
    );
  }
}

class PostItNote extends StatelessWidget {
  const PostItNote({
    required this.text,
    required this.author,
    required this.color,
    required this.seed,
    this.onDelete,
    super.key,
  });

  final String text;
  final String author;
  final Color color;
  final int seed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final angle = ((seed % 7) - 3) * 0.035; // pequeño giro determinista, no aleatorio en cada build
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 140,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(2, 4)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -14,
              left: 60,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFB0342A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: ConviveText.handwritten(fontSize: 17)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '— $author',
                      style: ConviveText.handwritten(fontSize: 13, color: const Color(0xFF2A2118).withValues(alpha: 0.7)),
                    ),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(Icons.close, size: 14, color: const Color(0xFF2A2118).withValues(alpha: 0.5)),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
