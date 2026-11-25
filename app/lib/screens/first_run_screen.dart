import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/buttons.dart';

/// Screen S1: First Run Screen (Section 10.1).
/// Explains Send vs Sync in two short lines. One action: Pair first device.
class FirstRunScreen extends StatelessWidget {
  final VoidCallback onPairDevice;

  const FirstRunScreen({Key? key, required this.onPairDevice}) : super(key: key);

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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  style: TandemTokens.text_md.copyWith(
                    color: TandemTokens.color_text.withOpacity(0.85),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: TandemTokens.space_6),
                TandemButton(
                  label: 'Pair device',
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
