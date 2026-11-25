import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

enum LinkLineState {
  directLocal,
  directInternet,
  relayed,
  connecting,
  offline,
}

/// LinkLine: The signature visual communication topology indicator (Section 8.1 & 8.3).
/// Adapts strictly to light/dark theme and never conveys connection state by color alone.
class LinkLine extends StatelessWidget {
  final LinkLineState state;
  final double length;
  final bool showLabel;
  final String? customLabel;

  const LinkLine({
    Key? key,
    required this.state,
    this.length = 64.0,
    this.showLabel = true,
    this.customLabel,
  }) : super(key: key);

  String get defaultLabel {
    switch (state) {
      case LinkLineState.directLocal:
        return 'Direct, same network';
      case LinkLineState.directInternet:
        return 'Direct, internet';
      case LinkLineState.relayed:
        return 'Through a relay (slower)';
      case LinkLineState.connecting:
        return 'Connecting';
      case LinkLineState.offline:
        return 'Offline';
    }
  }

  Color _lineColor(TandemTheme t) {
    switch (state) {
      case LinkLineState.directLocal:
      case LinkLineState.directInternet:
        return t.linkDirect;
      case LinkLineState.relayed:
        return t.linkRelay;
      case LinkLineState.connecting:
        return t.border;
      case LinkLineState.offline:
        return TandemTokens.color_transparent;
    }
  }

  Color _textColor(TandemTheme t) {
    switch (state) {
      case LinkLineState.directLocal:
      case LinkLineState.directInternet:
        return t.linkDirect;
      case LinkLineState.relayed:
        return t.linkRelayText;
      case LinkLineState.connecting:
      case LinkLineState.offline:
        return t.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final label = customLabel ?? defaultLabel;

    return Semantics(
      label: 'Connection status: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(length, 10.0),
            painter: _LinkLinePainter(
              state: state,
              color: _lineColor(t),
              offlineStroke: t.border,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: TandemTokens.space_2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TandemTokens.text_xs.copyWith(
                  color: _textColor(t),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkLinePainter extends CustomPainter {
  final LinkLineState state;
  final Color color;
  final Color offlineStroke;

  _LinkLinePainter({
    required this.state,
    required this.color,
    required this.offlineStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2.0;

    if (state == LinkLineState.offline) {
      final dotPaint = Paint()
        ..color = offlineStroke
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(3.0, cy), 2.5, dotPaint);
      canvas.drawCircle(Offset(size.width - 3.0, cy), 2.5, dotPaint);
      return;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(2.5, cy), 2.5, dotFill);
    canvas.drawCircle(Offset(size.width - 2.5, cy), 2.5, dotFill);

    const startX = 6.0;
    final endX = size.width - 6.0;

    if (state == LinkLineState.directLocal) {
      canvas.drawLine(Offset(startX, cy), Offset(endX, cy), linePaint);
    } else if (state == LinkLineState.directInternet ||
        state == LinkLineState.connecting) {
      const dashWidth = 6.0;
      const dashGap = 4.0;
      double x = startX;
      while (x < endX) {
        final next = (x + dashWidth).clamp(startX, endX);
        canvas.drawLine(Offset(x, cy), Offset(next, cy), linePaint);
        x += dashWidth + dashGap;
      }
    } else if (state == LinkLineState.relayed) {
      const dotStep = 6.0;
      double x = startX + 2.0;
      while (x < endX) {
        canvas.drawCircle(Offset(x, cy), 1.3, dotFill);
        x += dotStep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinkLinePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.color != color ||
      oldDelegate.offlineStroke != offlineStroke;
}
