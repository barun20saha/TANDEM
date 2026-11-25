import 'package:flutter/material.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

enum PairingPanelStep {
  showQR,
  scanQR,
  confirmMatch,
}

/// PairingPanel: QR code & 6-digit verification panel with tabular spacing and theme adaptation.
class PairingPanel extends StatelessWidget {
  final PairingPanelStep step;
  final String qrPayload;
  final String shortCode;
  final String remoteDeviceName;
  final VoidCallback? onConfirmMatch;
  final VoidCallback? onRejectMatch;

  const PairingPanel({
    Key? key,
    required this.step,
    required this.qrPayload,
    required this.shortCode,
    this.remoteDeviceName = 'Other device',
    this.onConfirmMatch,
    this.onRejectMatch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final spacedDigits = shortCode.split('').join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step == PairingPanelStep.showQR) ...[
            Text(
              'Share pairing credentials',
              style: t.sectionTitleStyle,
            ),
            const SizedBox(height: TandemTokens.space_1),
            Text(
              'Enter this code or scan the pairing URI on the second device.',
              style: t.secondaryStyle,
            ),
            const SizedBox(height: TandemTokens.space_4),
            Semantics(
              label: '6-digit verification code: $spacedDigits',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TandemTokens.space_4,
                  vertical: TandemTokens.space_3,
                ),
                decoration: BoxDecoration(
                  color: t.ground,
                  borderRadius: BorderRadius.circular(TandemTokens.radius_control),
                  border: Border.all(color: t.border, width: 0.5),
                ),
                child: SelectableText(
                  shortCode.isNotEmpty ? shortCode : 'Unavailable',
                  style: TandemTokens.text_2xl.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                    color: t.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: TandemTokens.space_3),
            Text('Pairing URI', style: t.captionStyle),
            const SizedBox(height: TandemTokens.space_1),
            SelectableText(
              qrPayload.isNotEmpty ? qrPayload : 'Unavailable',
              style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
            ),
          ] else if (step == PairingPanelStep.confirmMatch) ...[
            Text(
              'Confirm verification code',
              style: t.sectionTitleStyle,
            ),
            const SizedBox(height: TandemTokens.space_2),
            Text(
              'Does $remoteDeviceName show the code $shortCode?',
              style: t.bodyStyle,
            ),
            const SizedBox(height: TandemTokens.space_4),
            Wrap(
              spacing: TandemTokens.space_3,
              runSpacing: TandemTokens.space_2,
              children: [
                TandemButton(
                  label: 'Codes do not match',
                  variant: TandemButtonVariant.secondary,
                  onPressed: onRejectMatch,
                ),
                TandemButton(
                  label: 'Confirm match',
                  variant: TandemButtonVariant.primary,
                  onPressed: onConfirmMatch,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
