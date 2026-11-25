import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';

/// Vector brand mark for Tandem using theme tokens (Harbor Navy & Direct Blue).
class TandemLogo extends StatelessWidget {
  final double size;
  final bool showTile;

  const TandemLogo({
    Key? key,
    this.size = 28.0,
    this.showTile = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TandemLogoPainter(
          primaryColor: t.text,
          accentColor: t.linkDirect,
          tileColor: t.surface,
          borderColor: t.border,
          showTile: showTile,
        ),
      ),
    );
  }
}

class _TandemLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final Color tileColor;
  final Color borderColor;
  final bool showTile;

  _TandemLogoPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.tileColor,
    required this.borderColor,
    required this.showTile,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 256.0;
    canvas.save();
    canvas.scale(s, s);

    if (showTile) {
      final tileRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 248, 248),
        const Radius.circular(52),
      );
      canvas.drawRRect(tileRect, Paint()..color = tileColor);
      canvas.drawRRect(
        tileRect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
    }

    const double cx = 128.0;
    const double stemDx = 25.0;
    const double w = 22.0;
    const double gapW = 35.0;
    const double yBot = 178.0;
    const double yWaist = 120.0;
    const double earDx = 55.0;
    const double rEar = 34.0;
    const double earCy = yWaist - rEar;

    final leftStem = Path()
      ..moveTo(cx + 0.4, yBot + stemDx)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx, yBot), radius: stemDx),
        math.pi * 0.495,
        math.pi * 0.505,
        false,
      )
      ..lineTo(cx - stemDx, yWaist);

    final leftLobe = Path()
      ..moveTo(cx - stemDx, yWaist)
      ..lineTo(cx - earDx, yWaist)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx - earDx, earCy), radius: rEar),
        math.pi * 0.5,
        math.pi,
        false,
      )
      ..cubicTo(
        cx - earDx + 44.0,
        earCy - rEar,
        cx + stemDx,
        earCy - 18.0,
        cx + stemDx,
        yWaist - 10.0,
      );

    final rightStem = Path()
      ..moveTo(cx - 0.4, yBot + stemDx)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx, yBot), radius: stemDx),
        math.pi * 0.505,
        -math.pi * 0.505,
        false,
      )
      ..lineTo(cx + stemDx, yWaist);

    final rightLobe = Path()
      ..moveTo(cx + stemDx, yWaist)
      ..lineTo(cx + earDx, yWaist)
      ..arcTo(
        Rect.fromCircle(center: const Offset(cx + earDx, earCy), radius: rEar),
        math.pi * 0.5,
        -math.pi,
        false,
      )
      ..cubicTo(
        cx + earDx - 44.0,
        earCy - rEar,
        cx - stemDx,
        earCy - 18.0,
        cx - stemDx,
        yWaist,
      );

    final bridgeGap = Path()
      ..moveTo(86.0, 52.5)
      ..cubicTo(
        cx - earDx + 46.0,
        earCy - rEar,
        cx + stemDx - 2.0,
        earCy - 16.0,
        147.0,
        84.0,
      );

    canvas.saveLayer(const Rect.fromLTWH(0, 0, 256, 256), Paint());
    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(rightStem, accentPaint);
    canvas.drawPath(rightLobe, accentPaint);

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = gapW
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bridgeGap, clearPaint);

    final primaryPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(leftStem, primaryPaint);
    canvas.drawPath(leftLobe, primaryPaint);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TandemLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.tileColor != tileColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.showTile != showTile;
  }
}
