import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/buttons.dart';
import '../components/confirm_dialog.dart';

/// Screen S10: Settings (Section 10.1).
/// Network limits, Wi-Fi only, metered networks, relay config, "Hide from network", trash retention, startup.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _wifiOnly = false;
  bool _allowMetered = false;
  bool _hideFromNetwork = false;
  bool _enableRelays = true;
  bool _startOnLogin = true;
  double _trashRetentionDays = 30.0;

  void _showEmptyTrashDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Empty all trash?',
        body: 'This will permanently remove all recoverable files currently in .tandem-trash across all synced folders.',
        confirmLabel: 'Empty trash',
        cancelLabel: 'Keep files',
        isDestructive: true,
        onConfirm: () {
          Navigator.of(ctx).pop();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _buildSectionHeader('Network & Transfers'),
          _buildSwitchTile(
            title: 'Transfer over Wi-Fi only',
            subtitle: 'Pause transfers when connected to cellular data.',
            value: _wifiOnly,
            onChanged: (v) => setState(() => _wifiOnly = v),
          ),
          _buildSwitchTile(
            title: 'Allow metered networks',
            subtitle: 'Allow sync when connection is marked as metered by OS.',
            value: _allowMetered,
            onChanged: (v) => setState(() => _allowMetered = v),
          ),
          _buildSwitchTile(
            title: 'Hide from this network',
            subtitle: 'Temporarily stop local discovery announcements on current Wi-Fi.',
            value: _hideFromNetwork,
            onChanged: (v) => setState(() => _hideFromNetwork = v),
          ),
          const SizedBox(height: TandemTokens.space_5),

          _buildSectionHeader('Relays & Remote Connections'),
          _buildSwitchTile(
            title: 'Allow encrypted relays',
            subtitle: 'Connect via relay servers when direct peer connection is blocked by NAT.',
            value: _enableRelays,
            onChanged: (v) => setState(() => _enableRelays = v),
          ),
          const SizedBox(height: TandemTokens.space_5),

          _buildSectionHeader('Trash & Retention'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Trash retention duration', style: TandemTokens.text_sm.copyWith(fontWeight: FontWeight.w600)),
                    Text('${_trashRetentionDays.toInt()} days', style: TandemTokens.text_sm),
                  ],
                ),
                Slider(
                  value: _trashRetentionDays,
                  min: 7.0,
                  max: 90.0,
                  divisions: 83,
                  activeColor: TandemTokens.color_link_direct,
                  onChanged: (v) => setState(() => _trashRetentionDays = v),
                ),
                Text(
                  'Deleted files are safely kept in .tandem-trash for easy one-click recovery.',
                  style: TandemTokens.text_xs.copyWith(color: TandemTokens.color_text.withOpacity(0.6)),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TandemButton(
                  label: 'Empty trash now',
                  variant: TandemButtonVariant.secondary,
                  size: TandemButtonSize.sm,
                  onPressed: _showEmptyTrashDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),

          _buildSectionHeader('System Startup'),
          _buildSwitchTile(
            title: 'Start Tandem on login',
            subtitle: 'Run background sync service automatically on system startup.',
            value: _startOnLogin,
            onChanged: (v) => setState(() => _startOnLogin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TandemTokens.space_2),
      child: Text(
        title,
        style: TandemTokens.text_sm.copyWith(
          color: TandemTokens.color_text.withOpacity(0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: TandemTokens.space_2),
      decoration: BoxDecoration(
        color: TandemTokens.color_surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: TandemTokens.color_border, width: 0.5),
      ),
      child: SwitchListTile(
        title: Text(title, style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TandemTokens.text_xs.copyWith(color: TandemTokens.color_text.withOpacity(0.7))),
        value: value,
        activeColor: TandemTokens.color_link_direct,
        onChanged: onChanged,
      ),
    );
  }
}
