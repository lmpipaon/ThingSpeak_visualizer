import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class YAxisPainter extends CustomPainter {
  final double minY;
  final double maxY;
  final double width;
  final Color color;

  YAxisPainter({
    required this.minY,
    required this.maxY,
    required this.width,
    required this.color,
  });

  double normalize(double value) => (maxY == minY) ? 0.5 : (value - minY) / (maxY - minY);

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()..color = color.withOpacity(0.1)..strokeWidth = 0.5;
    final paintLine = Paint()..color = color..strokeWidth = 2;

    final values = [minY, minY + (maxY - minY) * 0.5, maxY];

    for (var v in values) {
      final y = size.height * (1 - normalize(v));
      canvas.drawLine(Offset(width - 5, y), Offset(size.width * 20, y), paintGrid);

      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 8);
      
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}