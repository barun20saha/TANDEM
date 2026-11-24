import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

enum PairingPanelStep {
  showQR,
  scanQR,
  confirmMatch,
}

/// PairingPanel: QR code and 6-digit verification code panel (Section 6 & 8.3).
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
    return Container(
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: TandemTokens.color_surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: TandemTokens.color_border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Pair with another device',
            style: TandemTokens.text_xl.copyWith(
              fontFamily: 'Familjen Grotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TandemTokens.space_2),
          Text(
            'Scan this code on your other device. Both devices must confirm.',
            style: TandemTokens.text_sm.copyWith(
              color: TandemTokens.color_text.withOpacity(0.75),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TandemTokens.space_5),

          // Code Display (Tabular figures)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TandemTokens.space_4,
              vertical: TandemTokens.space_3,
            ),
            decoration: BoxDecoration(
              color: TandemTokens.color_ground,
              borderRadius: BorderRadius.circular(TandemTokens.radius_control),
            ),
            child: Text(
              shortCode,
              style: TandemTokens.text_2xl.copyWith(
                letterSpacing: 4.0,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                color: TandemTokens.color_link_direct,
              ),
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),

          if (step == PairingPanelStep.confirmMatch) ...[
            Text(
              'Does your other device show the code $shortCode?',
              style: TandemTokens.text_md,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TandemTokens.space_5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TandemButton(
                  label: 'Codes do not match',
                  variant: TandemButtonVariant.secondary,
                  onPressed: onRejectMatch,
                ),
                const SizedBox(width: TandemTokens.space_3),
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
