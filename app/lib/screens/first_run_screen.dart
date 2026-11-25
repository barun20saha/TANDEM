import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/tandem_logo.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

/// Screen S1: First Run Screen.
/// Honest, quiet utility onboarding introducing Send vs Sync with real local device identity.
class FirstRunScreen extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final VoidCallback onPairDevice;
  final VoidCallback? onOpenHealth;

  const FirstRunScreen({
    Key? key,
    required this.deviceName,
    required this.deviceId,
    required this.onPairDevice,
    this.onOpenHealth,
  }) : super(key: key);

  Widget _modeRow(TandemTheme t, String label, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TandemTokens.space_3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84.0,
            child: Text(
              label,
              style: t.bodyStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: TandemTokens.space_3),
          Expanded(
            child: Text(description, style: t.bodyStyle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      body: SingleChildScrollView(
        child: WorkspacePane(
          maxWidth: 680.0,
          padding: EdgeInsets.symmetric(
            horizontal: t.isDesktop ? TandemTokens.space_7 : TandemTokens.space_4,
            vertical: t.isDesktop ? TandemTokens.space_7 : TandemTokens.space_6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const TandemLogo(size: 36.0),
                  const SizedBox(width: TandemTokens.space_3),
                  Text(
                    'Tandem',
                    style: TandemTokens.text_2xl.copyWith(
                      fontSize: t.isDesktop ? 30.0 : 26.0,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TandemTokens.space_2),
              Text(
                'Direct peer-to-peer file transfer and folder synchronization.',
                style: t.secondaryStyle.copyWith(fontSize: t.bodyFontSize),
              ),
              const SizedBox(height: TandemTokens.space_5),
              Divider(height: 1.0, color: t.border),
              _modeRow(
                t,
                'Send',
                'Push files or photos once to a paired device without setting up a shared folder.',
              ),
              Divider(height: 1.0, color: t.border),
              _modeRow(
                t,
                'Sync',
                'Keep a folder identical across your paired devices over LAN or encrypted links.',
              ),
              Divider(height: 1.0, color: t.border),
              if (deviceName.isNotEmpty || deviceId.isNotEmpty) ...[
                const SizedBox(height: TandemTokens.space_5),
                Text('This device', style: t.captionStyle),
                const SizedBox(height: TandemTokens.space_1),
                Text(
                  deviceName.isNotEmpty ? deviceName : 'Unnamed device',
                  style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                if (deviceId.isNotEmpty) ...[
                  const SizedBox(height: TandemTokens.space_1),
                  SelectableText(
                    deviceId,
                    style: t.monoStyle.copyWith(
                      fontSize: t.isTabletOrLarger ? 12.0 : 11.0,
                      color: t.mutedText,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: TandemTokens.space_6),
              Wrap(
                spacing: TandemTokens.space_3,
                runSpacing: TandemTokens.space_3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TandemButton(
                    label: 'Pair first device',
                    variant: TandemButtonVariant.primary,
                    size: TandemButtonSize.lg,
                    autofocus: true,
                    onPressed: onPairDevice,
                  ),
                  if (onOpenHealth != null)
                    TandemButton(
                      label: 'System health check',
                      variant: TandemButtonVariant.secondary,
                      size: TandemButtonSize.lg,
                      onPressed: onOpenHealth,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
