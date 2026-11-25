import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../theme/tokens.dart';

/// Screen S1: First Run Screen (Section 10.1).
/// Explains Send vs Sync in two short lines and shows this device's real name and pairing action.
class FirstRunScreen extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final VoidCallback onPairDevice;

  const FirstRunScreen({
    Key? key,
    required this.deviceName,
    required this.deviceId,
    required this.onPairDevice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480.0),
          child: Padding(
            padding: const EdgeInsets.all(TandemTokens.space_6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tandem',
                  style: TandemTokens.text_2xl.copyWith(
                    fontFamily: 'Familjen Grotesk',
                    fontWeight: FontWeight.w700,
                    color: TandemTokens.color_text,
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                Text(
                  'Send files nearby with no internet.\nKeep folders identical across all your devices anywhere.',
                  style: TandemTokens.text_md.copyWith(height: 1.5),
                ),
                if (deviceName.isNotEmpty) ...[
                  const SizedBox(height: TandemTokens.space_4),
                  Text(
                    'This device: $deviceName',
                    style: TandemTokens.text_sm.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: TandemTokens.space_5),
                TandemButton(
                  label: 'Pair device',
                  variant: TandemButtonVariant.primary,
                  size: TandemButtonSize.lg,
                  onPressed: onPairDevice,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
