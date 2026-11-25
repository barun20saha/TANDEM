import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum LinkLineState {
  directLocal,
  directInternet,
  relayed,
  connecting,
  offline,
}

/// LinkLine: Signature visual connection element between devices (Section 5.1 & 8.3).
/// Always paired with a text label. Never conveys state by color alone.
class LinkLine extends StatelessWidget {
  final LinkLineState state;
  final double length;
  final bool isHorizontal;

  const LinkLine({
    Key? key,
    required this.state,
    this.length = 80.0,
    this.isHorizontal = true,
  }) : super(key: key);

  String get labelText {
    switch (state) {
      case LinkLineState.directLocal:
        return 'Direct, same network';
      case LinkLineState.directInternet:
        return 'Direct, over the internet';
      case LinkLineState.relayed:
        return 'Through a relay (slower)';
      case LinkLineState.connecting:
        return 'Connecting';
      case LinkLineState.offline:
        return 'Not reachable';
    }
  }

  Color get lineColor {
    switch (state) {
      case LinkLineState.directLocal:
      case LinkLineState.directInternet:
        return TandemTokens.color_link_direct;
      case LinkLineState.relayed:
        return TandemTokens.color_link_relay;
      case LinkLineState.connecting:
        return TandemTokens.color_border;
      case LinkLineState.offline:
        return TandemTokens.color_transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen reader accessible semantic node
    return Semantics(
      label: 'Connection status: $labelText',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            size: isHorizontal ? Size(length, 4.0) : Size(4.0, length),
            painter: _LinkLinePainter(
              state: state,
              color: lineColor,
              isHorizontal: isHorizontal,
            ),
          ),
          const SizedBox(height: TandemTokens.space_1),
          Text(
            labelText,
            style: TandemTokens.text_xs.copyWith(
              color: state == LinkLineState.relayed
                  ? TandemTokens.color_link_relay_text
                  : TandemTokens.color_text,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkLinePainter extends CustomPainter {
  final LinkLineState state;
  final Color color;
  final bool isHorizontal;

  _LinkLinePainter({
    required this.state,
    required this.color,
    required this.isHorizontal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (state == LinkLineState.offline) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final start = isHorizontal ? Offset(0, size.height / 2) : Offset(size.width / 2, 0);
    final end = isHorizontal ? Offset(size.width, size.height / 2) : Offset(size.width / 2, size.height);

    switch (state) {
      case LinkLineState.directLocal:
        // Solid line
        canvas.drawLine(start, end, paint);
        break;

      case LinkLineState.directInternet:
        // Dashed line (6px dash, 4px gap)
        _drawDashed(canvas, start, end, paint, dash: 6.0, gap: 4.0);
        break;

      case LinkLineState.relayed:
        // Dotted line (2px dot, 4px gap)
        _drawDashed(canvas, start, end, paint, dash: 2.0, gap: 4.0);
        break;

      case LinkLineState.connecting:
        // Muted dashed line
        paint.color = TandemTokens.color_border;
        _drawDashed(canvas, start, end, paint, dash: 4.0, gap: 4.0);
        break;

      case LinkLineState.offline:
        break;
    }
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint, {required double dash, required double gap}) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLen = (dx != 0) ? dx.abs() : dy.abs();

    double current = 0;
    while (current < totalLen) {
      final segStart = isHorizontal
          ? Offset(start.dx + current, start.dy)
          : Offset(start.dx, start.dy + current);
      final segLen = (current + dash > totalLen) ? totalLen - current : dash;
      final segEnd = isHorizontal
          ? Offset(segStart.dx + segLen, start.dy)
          : Offset(start.dx, segStart.dy + segLen);

      canvas.drawLine(segStart, segEnd, paint);
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LinkLinePainter old) =>
      old.state != state || old.color != color;
}
