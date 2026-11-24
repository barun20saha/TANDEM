import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/link_line.dart';
import '../components/banner.dart';
import '../components/buttons.dart';

/// Screen S6: Device Detail and Link Status (Section 5.1 & 10.1).
/// Displays per-interface accounting, honest relay disclosures, and real tabular metrics.
class LinkStatusScreen extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final LinkLineState linkState;
  final String activeInterface; // "Wi-Fi (192.168.1.50)", "Ethernet", "Relay"
  final String uploadSpeed;
  final String downloadSpeed;
  final bool isRelayed;

  const LinkStatusScreen({
    Key? key,
    required this.deviceName,
    required this.deviceId,
    this.linkState = LinkLineState.directLocal,
    this.activeInterface = 'Wi-Fi · 192.168.1.50',
    this.uploadSpeed = '18.4 MB/s',
    this.downloadSpeed = '24.1 MB/s',
    this.isRelayed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        backgroundColor: TandemTokens.color_surface,
      ),
      backgroundColor: TandemTokens.color_ground,
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_5),
        children: [
          // 1. Connection Topology Card
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDeviceBadge('This Device', Icons.laptop_mac),
                    LinkLine(
                      state: linkState,
                      length: 120.0,
                    ),
                    _buildDeviceBadge(deviceName, Icons.phone_android),
                  ],
                ),
                const SizedBox(height: TandemTokens.space_4),
                Text(
                  'Active Link: $activeInterface',
                  style: TandemTokens.text_sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_4),

          // 2. Honest Relay Disclosure (Section 5.1 & 5.6)
          if (linkState == LinkLineState.relayed || isRelayed) ...[
            BannerNotification(
              variant: BannerVariant.warning,
              message:
                  'This device is connected through a relay. Transfers are end-to-end encrypted but slower. Set up your own relay for better speed.',
              actionLabel: 'Relay Settings',
              onAction: () {},
            ),
            const SizedBox(height: TandemTokens.space_4),
          ],

          // 3. Per-Network Real-Time Metrics (Plexo model, Section 5.7)
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer Rates',
                  style: TandemTokens.text_md.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Download', downloadSpeed, Icons.arrow_downward),
                    _buildMetric('Upload', uploadSpeed, Icons.arrow_upward),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_4),

          // 4. Discovery Self-Test Status (Section 5.4)
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network Diagnostics',
                  style: TandemTokens.text_md.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                _buildDiagnosticRow('Local Discovery (UDP 21027)', 'Operational', TandemTokens.color_ok),
                _buildDiagnosticRow('Firewall Status', 'Inbound open', TandemTokens.color_ok),
                _buildDiagnosticRow('Internet Connectivity', 'Offline (Local Sync Active)', TandemTokens.color_text),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),

          // 5. Advanced / Unpair
          Center(
            child: TandemButton(
              label: 'Unpair this device',
              variant: TandemButtonVariant.destructive,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceBadge(String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 36.0, color: TandemTokens.color_link_direct),
        const SizedBox(height: TandemTokens.space_1),
        Text(
          label,
          style: TandemTokens.text_xs.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.0, color: TandemTokens.color_link_direct),
        const SizedBox(width: TandemTokens.space_2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TandemTokens.text_xs),
            Text(
              value,
              style: TandemTokens.text_lg.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticRow(String label, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TandemTokens.space_1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TandemTokens.text_sm),
          Text(
            status,
            style: TandemTokens.text_sm.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
