import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

enum TransferState {
  sending,
  receiving,
  queued,
  paused,
  failed,
  done,
}

/// TransferRow: Real-time transfer row with tabular speeds and link interface label.
class TransferRow extends StatelessWidget {
  final String fileName;
  final TransferState state;
  final double progress;
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
    this.speedText = '0 B/s',
    this.timeLeftText = '0 B',
    this.interfaceUsed = 'direct-local',
    this.failureReason,
    this.onRetry,
  }) : super(key: key);

  Color _progressColor(TandemTheme t) {
    switch (state) {
      case TransferState.failed:
        return t.danger;
      case TransferState.done:
        return t.ok;
      case TransferState.paused:
      case TransferState.queued:
        return t.border;
      case TransferState.sending:
      case TransferState.receiving:
        return t.linkDirect;
    }
  }

  String get _stateLabel {
    switch (state) {
      case TransferState.done:
        return 'Done';
      case TransferState.failed:
        return 'Failed';
      case TransferState.paused:
        return 'Paused';
      case TransferState.queued:
        return 'Queued';
      case TransferState.receiving:
        return 'Receiving';
      case TransferState.sending:
        return 'Sending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final barColor = _progressColor(t);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_3,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          bottom: BorderSide(color: t.border, width: 0.5),
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
                  style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: TandemTokens.space_3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TandemTokens.space_2,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: t.ground,
                  borderRadius: BorderRadius.circular(TandemTokens.radius_control),
                  border: Border.all(color: t.border, width: 0.5),
                ),
                child: Text(
                  interfaceUsed,
                  style: t.captionStyle.copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: TandemTokens.space_3),
              Text(
                _stateLabel,
                style: TandemTokens.text_sm.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.0),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4.0,
              backgroundColor: t.border.withAlpha(80),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: TandemTokens.space_2),
          Row(
            children: [
              Text(
                speedText,
                style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
              ),
              const Spacer(),
              Text(
                timeLeftText,
                style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
              ),
            ],
          ),
          if (state == TransferState.failed && failureReason != null) ...[
            const SizedBox(height: TandemTokens.space_2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    failureReason!,
                    style: TandemTokens.text_sm.copyWith(color: t.danger),
                  ),
                ),
                if (onRetry != null)
                  TandemButton(
                    label: 'Retry transfer',
                    variant: TandemButtonVariant.secondary,
                    onPressed: onRetry,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
