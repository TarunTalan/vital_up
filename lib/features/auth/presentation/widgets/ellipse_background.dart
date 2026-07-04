import 'package:flutter/material.dart';

class EllipseBackground extends StatelessWidget {
  final double height;

  const EllipseBackground({super.key, this.height = 140.0});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _EllipsePainter(color: colors.secondary),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final Color color;

  _EllipsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.lineTo(0, size.height * 0.7);
    
    // Draw a smooth quadratic curve to create the ellipse/arc effect at the bottom
    path.quadraticBezierTo(
      size.width / 2, 
      size.height * 1.1, 
      size.width, 
      size.height * 0.7,
    );
    
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
