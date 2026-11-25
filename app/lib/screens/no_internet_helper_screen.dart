import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

/// Screen S8: No-Internet Helper (Section 5.3 Flows B to E & Section 10.1).
class NoInternetHelperScreen extends StatefulWidget {
  const NoInternetHelperScreen({Key? key}) : super(key: key);

  @override
  State<NoInternetHelperScreen> createState() => _NoInternetHelperScreenState();
}

class _NoInternetHelperScreenState extends State<NoInternetHelperScreen> {
  String _selectedFlow = 'hotspot-phone';

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text('Transfer with no internet', style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: WorkspacePane(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BannerNotification(
                variant: BannerVariant.info,
                message:
                    'Zero-internet mode: transfers move directly across your local wireless network or hotspot.',
              ),
              const SizedBox(height: TandemTokens.space_4),
              Text('Choose connection scenario', style: t.sectionTitleStyle),
              const SizedBox(height: TandemTokens.space_3),
              _buildFlowOption(
                t,
                id: 'hotspot-phone',
                title: 'Use a phone hotspot (no Wi-Fi router needed)',
                subtitle: 'Turn on Personal Hotspot on one phone; join from your laptop or second phone.',
              ),
              Divider(height: 1.0, color: t.border),
              _buildFlowOption(
                t,
                id: 'hotspot-linux',
                title: 'Create hotspot from a Linux laptop',
                subtitle: 'Opens a temporary 2.4/5 GHz hotspot via NetworkManager.',
              ),
              Divider(height: 1.0, color: t.border),
              _buildFlowOption(
                t,
                id: 'client-isolation',
                title: 'Router blocks direct peer traffic (AP isolation)',
                subtitle: 'Guidance when campus or hotel Wi-Fi isolates devices.',
              ),
              const SizedBox(height: TandemTokens.space_5),
              if (_selectedFlow == 'hotspot-phone') _buildPhoneHotspotGuide(t),
              if (_selectedFlow == 'hotspot-linux') _buildLinuxHotspotGuide(t),
              if (_selectedFlow == 'client-isolation') _buildIsolationGuide(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowOption(
    TandemTheme t, {
    required String id,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedFlow == id;
    return Material(
      color: selected ? t.linkDirect.withAlpha(20) : t.surface,
      child: InkWell(
        onTap: () => setState(() => _selectedFlow = id),
        child: Padding(
          padding: const EdgeInsets.all(TandemTokens.space_4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? t.linkDirect : t.mutedText,
              ),
              const SizedBox(width: TandemTokens.space_3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2.0),
                    Text(subtitle, style: t.secondaryStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneHotspotGuide(TandemTheme t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Steps for Android / iOS hotspot', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_3),
          Text(
            '1. Enable Mobile Hotspot on one phone (mobile data can stay off).\n'
            '2. Connect your second device to that hotspot Wi-Fi network.\n'
            '3. Return to Tandem — local announcements detect peers on the hotspot subnet automatically.',
            style: t.bodyStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildLinuxHotspotGuide(TandemTheme t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create hotspot via NetworkManager', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Text(
            'Run this command on a Linux host with an AP-capable Wi-Fi adapter:',
            style: t.secondaryStyle,
          ),
          const SizedBox(height: TandemTokens.space_3),
          SelectableText(
            'nmcli device wifi hotspot ifname wlan0 ssid TandemHotspot password <passphrase>',
            style: t.monoStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildIsolationGuide(TandemTheme t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client isolation workaround', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Text(
            'Public, hotel, or campus Wi-Fi networks often isolate wireless clients from talking directly. Switch both devices to a phone hotspot or USB tether so direct LAN discovery works.',
            style: t.bodyStyle,
          ),
          const SizedBox(height: TandemTokens.space_4),
          TandemButton(
            label: 'Switch to phone hotspot steps',
            variant: TandemButtonVariant.secondary,
            onPressed: () => setState(() => _selectedFlow = 'hotspot-phone'),
          ),
        ],
      ),
    );
  }
}
