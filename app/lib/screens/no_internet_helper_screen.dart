import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/banner.dart';
import '../components/buttons.dart';

enum OfflineFlowType {
  flowBPhoneHotspot,
  flowCLaptopHotspot,
  flowDMacGuidance,
  flowEClientIsolation,
}

/// Screen S8: No-Internet Helper Screen (Section 5.3 & 10.1).
/// Guides users through Flows B to E with step-by-step visual instructions and QR codes.
class NoInternetHelperScreen extends StatelessWidget {
  final OfflineFlowType flowType;
  final String hotspotSSID;
  final String hotspotPassword;
  final String wifiQRPayload;

  const NoInternetHelperScreen({
    Key? key,
    this.flowType = OfflineFlowType.flowBPhoneHotspot,
    this.hotspotSSID = 'Tandem-Hotspot',
    this.hotspotPassword = 'tandem-secure-pass',
    this.wifiQRPayload = 'WIFI:T:WPA;S:Tandem-Hotspot;P:tandem-secure-pass;;',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Without Internet'),
        backgroundColor: TandemTokens.color_surface,
      ),
      backgroundColor: TandemTokens.color_ground,
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_5),
        children: [
          // 1. Context Explanation Banner
          if (flowType == OfflineFlowType.flowEClientIsolation) ...[
            BannerNotification(
              variant: BannerVariant.warning,
              message:
                  "Can't see nearby device. This network may stop devices from finding each other (client isolation). Make a hotspot on one device and connect the other to it.",
              actionLabel: 'Make a hotspot',
              onAction: () {},
            ),
            const SizedBox(height: TandemTokens.space_4),
          ],

          // 2. Guided Step Card
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_5),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: TandemTokens.text_xl.copyWith(
                    fontFamily: 'Familjen Grotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                Text(
                  _getDescription(),
                  style: TandemTokens.text_md,
                ),
                const SizedBox(height: TandemTokens.space_5),

                // Wi-Fi QR Code Box (Flow B & C)
                if (flowType == OfflineFlowType.flowBPhoneHotspot ||
                    flowType == OfflineFlowType.flowCLaptopHotspot) ...[
                  Center(
                    child: Container(
                      width: 180.0,
                      height: 180.0,
                      decoration: BoxDecoration(
                        color: TandemTokens.color_ground,
                        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
                        border: Border.all(color: TandemTokens.color_border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 96.0,
                            color: TandemTokens.color_text,
                          ),
                          const SizedBox(height: TandemTokens.space_1),
                          Text(
                            'Scan Wi-Fi QR Code',
                            style: TandemTokens.text_xs.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: TandemTokens.space_4),
                  Center(
                    child: Text(
                      'Network: $hotspotSSID  ·  Password: $hotspotPassword',
                      style: TandemTokens.text_sm.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Flow D: macOS guidance
                if (flowType == OfflineFlowType.flowDMacGuidance) ...[
                  _buildStep('1', 'Turn on Mobile Hotspot on your phone (no cellular data needed).'),
                  _buildStep('2', 'Click the Wi-Fi icon in the macOS menu bar.'),
                  _buildStep('3', 'Select your phone’s network to connect.'),
                ],
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),

          Center(
            child: TandemButton(
              label: 'Done, return to devices',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (flowType) {
      case OfflineFlowType.flowBPhoneHotspot:
        return 'Flow B: Phone Makes the Network';
      case OfflineFlowType.flowCLaptopHotspot:
        return 'Flow C: Laptop Makes the Network';
      case OfflineFlowType.flowDMacGuidance:
        return 'Flow D: Connect Mac to Phone Network';
      case OfflineFlowType.flowEClientIsolation:
        return 'Flow E: Network Isolation Detected';
    }
  }

  String _getDescription() {
    switch (flowType) {
      case OfflineFlowType.flowBPhoneHotspot:
        return 'Your phone has created an isolated Wi-Fi network. Connect your laptop to this network by scanning the QR code or entering credentials.';
      case OfflineFlowType.flowCLaptopHotspot:
        return 'Your laptop has created an ad-hoc Wi-Fi hotspot. Connect your other devices using the QR code below.';
      case OfflineFlowType.flowDMacGuidance:
        return 'macOS does not permit apps to start an ad-hoc hotspot programmatically. Follow these steps to connect your Mac to your phone’s local network.';
      case OfflineFlowType.flowEClientIsolation:
        return 'This guest or corporate network blocks devices from seeing each other. Use your phone or laptop to create an ad-hoc hotspot to bypass network isolation.';
    }
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TandemTokens.space_2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12.0,
            backgroundColor: TandemTokens.color_link_direct,
            child: Text(
              num,
              style: TandemTokens.text_xs.copyWith(color: TandemTokens.color_on_primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: TandemTokens.space_3),
          Expanded(
            child: Text(text, style: TandemTokens.text_md),
          ),
        ],
      ),
    );
  }
}
