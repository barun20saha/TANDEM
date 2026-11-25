import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/confirm_dialog.dart';
import '../components/link_line.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S7: Link Status & Diagnostics (Section 10.1).
/// Renders real connection type, throughput, addresses, and system diagnostics.
class LinkStatusScreen extends StatefulWidget {
  final TandemController controller;
  final TandemDevice device;
  final SystemHealth? health;

  const LinkStatusScreen({
    Key? key,
    required this.controller,
    required this.device,
    this.health,
  }) : super(key: key);

  @override
  State<LinkStatusScreen> createState() => _LinkStatusScreenState();
}

class _LinkStatusScreenState extends State<LinkStatusScreen> {
  bool _busy = false;
  String? _errorText;

  Future<void> _confirmUnpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Unpair ${widget.device.name}?',
        body:
            'Syncing with ${widget.device.name} will stop. Existing files on either device will stay intact.',
        confirmLabel: 'Unpair device',
        cancelLabel: 'Cancel',
        isDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      await widget.controller.unpairDevice(widget.device.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Widget _metricRow(String label, String value) {
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
              style: TandemTokens.text_sm.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final health = widget.health;
    final displayName = device.name.isNotEmpty ? device.name : device.id;

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: Text(displayName),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (_errorText != null) ...[
            BannerNotification(
              variant: BannerVariant.error,
              message: _errorText!,
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
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
                  device.id,
                  style: TandemTokens.text_xs.copyWith(
                    fontFamily: 'monospace',
                    color: TandemTokens.color_text.withAlpha(153),
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                LinkLine(state: parseLinkState(device.linkState)),
                const SizedBox(height: TandemTokens.space_4),
                const Divider(height: 1.0, color: TandemTokens.color_border),
                const SizedBox(height: TandemTokens.space_3),
                _metricRow(
                  'Upload speed',
                  formatSpeed(device.uploadRateBytesPerSec),
                ),
                _metricRow(
                  'Download speed',
                  formatSpeed(device.downloadRateBytesPerSec),
                ),
                _metricRow(
                  'Status',
                  device.isPaired ? 'Paired' : 'Nearby (not paired)',
                ),
                _metricRow(
                  'Last seen',
                  device.lastSeen.isNotEmpty ? device.lastSeen : 'Unknown',
                ),
                _metricRow(
                  'Known addresses',
                  device.addresses.isEmpty
                      ? 'None reported'
                      : device.addresses.join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(height: TandemTokens.space_5),
          Text(
            'Daemon diagnostics',
            style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TandemTokens.space_3),
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: health == null
                ? Text(
                    'System health has not been reported by the daemon yet.',
                    style: TandemTokens.text_sm.copyWith(
                      color: TandemTokens.color_text.withAlpha(153),
                    ),
                  )
                : Column(
                    children: [
                      _metricRow(
                        'Sync engine',
                        health.engineReady ? 'Ready' : 'Not ready',
                      ),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _metricRow(
                        'Sync port',
                        health.syncPortOpen ? 'Listening' : 'Closed',
                      ),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _metricRow(
                        'Local discovery',
                        health.discoveryWorks ? 'Active' : 'Unavailable',
                      ),
                      const Divider(height: 1.0, color: TandemTokens.color_border),
                      _metricRow('Firewall', health.firewallState),
                    ],
                  ),
          ),
          const SizedBox(height: TandemTokens.space_5),
          Row(
            children: [
              TandemButton(
                label: 'Refresh status',
                variant: TandemButtonVariant.secondary,
                isLoading: _busy,
                onPressed: _busy ? null : () => widget.controller.refreshAll(),
              ),
              if (device.isPaired) ...[
                const SizedBox(width: TandemTokens.space_3),
                TandemButton(
                  label: 'Unpair device',
                  variant: TandemButtonVariant.destructive,
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirmUnpair,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
