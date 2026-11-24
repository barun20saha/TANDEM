import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum TransferState {
  sending,
  receiving,
  queued,
  paused,
  failed,
  done,
}

/// TransferRow: Details an active or finished file transfer with real tabular figures (Section 8.3).
class TransferRow extends StatelessWidget {
  final String fileName;
  final TransferState state;
  final double progress; // 0.0 to 1.0
  final String speedText;
  final String timeLeftText;
  final String interfaceUsed;
  final String? failureReason;
  final VoidCallback? onRetry;

  const TransferRow({
    Key? key,
    required this.fileName,
    required this.state,
    this.progress = 0.0,
    this.speedText = '0 MB/s',
    this.timeLeftText = 'calculating...',
    this.interfaceUsed = 'Wi-Fi',
    this.failureReason,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_3,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TandemTokens.color_border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fileName,
                  style: TandemTokens.text_sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                state == TransferState.done
                    ? 'Complete'
                    : '$speedText · $timeLeftText',
                style: TandemTokens.text_xs.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: TandemTokens.color_text,
                ),
              ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_2),

          // Linear progress bar
          if (state == TransferState.sending || state == TransferState.receiving) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(TandemTokens.radius_control),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: TandemTokens.color_border,
                valueColor: const AlwaysStoppedAnimation<Color>(TandemTokens.color_link_direct),
                minHeight: 4.0,
              ),
            ),
            const SizedBox(height: TandemTokens.space_1),
            Text(
              'Via $interfaceUsed',
              style: TandemTokens.text_xs.copyWith(
                color: TandemTokens.color_text.withOpacity(0.6),
              ),
            ),
          ],

          if (state == TransferState.failed) ...[
            Text(
              failureReason ?? 'Transfer interrupted',
              style: TandemTokens.text_xs.copyWith(color: TandemTokens.color_danger),
            ),
            if (onRetry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry transfer'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
