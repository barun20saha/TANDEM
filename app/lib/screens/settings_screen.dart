import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';

/// Screen S10: Settings & Daemon Runtime Info (Section 10.1).
class SettingsScreen extends StatelessWidget {
  final TandemController controller;

  const SettingsScreen({Key? key, required this.controller}) : super(key: key);

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TandemTokens.space_2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TandemTokens.text_md.copyWith(
              color: TandemTokens.color_text.withAlpha(153),
            ),
          ),
          const SizedBox(width: TandemTokens.space_3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TandemTokens.text_sm.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DaemonStatus? status = controller.status;

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          Text(
            'Local Daemon',
            style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TandemTokens.space_2),
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: status == null
                ? const Text(
                    'Daemon status is not available yet.',
                    style: TandemTokens.text_md,
                  )
                : Column(
                    children: [
                      _infoTile('Device name', status.myDeviceName),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile('Device ID', status.myDeviceId),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile('Daemon version', status.version),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile('Daemon state', status.state),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile('Sync port', '${status.syncPort}'),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile('Discovery port', '${status.discoveryPort}'),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _infoTile(
                        'Internet reachable',
                        status.hasInternet ? 'Yes' : 'No (LAN / offline)',
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: TandemTokens.space_4),
          Align(
            alignment: Alignment.centerLeft,
            child: TandemButton(
              label: 'Refresh daemon state',
              variant: TandemButtonVariant.secondary,
              onPressed: () => controller.refreshAll(),
            ),
          ),
        ],
      ),
    );
  }
}
