import 'package:flutter/material.dart';

class SecurityWatermark extends StatelessWidget {
  const SecurityWatermark({
    super.key,
    required this.child,
    required this.userLabel,
    required this.timestampLabel,
  });

  final Widget child;
  final String userLabel;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final text = 'VerificArte • $userLabel • $timestampLabel';
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: Opacity(
            opacity: 0.17,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  painter: _WatermarkPainter(
                    text: text,
                    size: constraints.biggest,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.text, required this.size});

  final String text;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final diagonalStepX = painter.width + 72;
    final diagonalStepY = painter.height + 46;

    canvas.save();
    canvas.rotate(-0.35);

    for (double y = -size.height; y < size.height * 2; y += diagonalStepY) {
      for (double x = -size.width; x < size.width * 2; x += diagonalStepX) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.size != size;
  }
}
