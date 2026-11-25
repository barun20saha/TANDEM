import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/confirm_dialog.dart';
import '../components/link_line.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S6: Link Status & Diagnostics (Section 10.1).
/// Renders real connection type, relay disclosure, throughput, addresses, and system checks.
class LinkStatusScreen extends StatefulWidget {
  final TandemController controller;
  final TandemDevice device;
  final SystemHealth? health;
  final bool embedded;
  final VoidCallback? onClose;

  const LinkStatusScreen({
    Key? key,
    required this.controller,
    required this.device,
    this.health,
    this.embedded = false,
    this.onClose,
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
            'Syncing with ${widget.device.name} will stop. Existing files on either device remain intact.',
        confirmLabel: 'Unpair device',
        cancelLabel: 'Keep device',
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
      if (mounted) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Widget _metricRow(TandemTheme t, String label, String value, {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_4,
        vertical: TandemTokens.space_3,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150.0,
            child: Text(label, style: t.secondaryStyle),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono ? t.monoStyle : t.tabularBodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final device = widget.device;
    final health = widget.health;
    final displayName = device.name.isNotEmpty ? device.name : device.id;
    final linkState = parseLinkState(device.linkState);

    final content = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: t.pageTitleStyle),
                    const SizedBox(height: 2.0),
                    SelectableText(
                      device.id,
                      style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                TandemButton(
                  label: 'Back',
                  variant: TandemButtonVariant.quiet,
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_4),
          LinkLine(state: linkState, length: 96.0),
          const SizedBox(height: TandemTokens.space_4),
          if (_errorText != null) ...[
            BannerNotification(
              variant: BannerVariant.error,
              message: _errorText!,
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
          if (linkState == LinkLineState.relayed) ...[
            BannerNotification(
              variant: BannerVariant.warning,
              message: TandemStrings.get('link.relayed.help'),
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
          Text('Link telemetry', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Divider(height: 1.0, color: t.border),
          _metricRow(t, 'Upload speed', formatSpeed(device.uploadRateBytesPerSec), mono: true),
          _metricRow(t, 'Download speed', formatSpeed(device.downloadRateBytesPerSec), mono: true),
          _metricRow(
            t,
            'Pairing state',
            device.isPaired ? 'Paired' : 'Nearby (not paired)',
          ),
          _metricRow(
            t,
            'Last seen',
            device.lastSeen.isNotEmpty ? device.lastSeen : 'Unknown',
          ),
          _metricRow(
            t,
            'Known addresses',
            device.addresses.isEmpty ? 'None reported' : device.addresses.join(', '),
            mono: device.addresses.isNotEmpty,
          ),
          const SizedBox(height: TandemTokens.space_5),
          Text('Local daemon diagnostics', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Divider(height: 1.0, color: t.border),
          if (health == null)
            Container(
              width: double.infinity,
              color: t.surface,
              padding: const EdgeInsets.all(TandemTokens.space_4),
              child: Text(
                'System health has not been reported by the daemon yet.',
                style: t.secondaryStyle,
              ),
            )
          else ...[
            _metricRow(t, 'Sync engine', health.engineReady ? 'Ready' : 'Not ready'),
            _metricRow(t, 'Sync port', health.syncPortOpen ? 'Listening' : 'Closed'),
            _metricRow(
              t,
              'Local discovery',
              health.discoveryWorks ? 'Active' : 'Unavailable',
            ),
            _metricRow(
              t,
              'Firewall',
              health.firewallState.isEmpty
                  ? 'Unknown'
                  : '${health.firewallState[0].toUpperCase()}${health.firewallState.substring(1)}',
            ),
          ],
          const SizedBox(height: TandemTokens.space_5),
          Wrap(
            spacing: TandemTokens.space_3,
            runSpacing: TandemTokens.space_2,
            children: [
              TandemButton(
                label: 'Refresh status',
                variant: TandemButtonVariant.secondary,
                isLoading: _busy,
                onPressed: _busy ? null : () => widget.controller.refreshAll(),
              ),
              if (device.isPaired)
                TandemButton(
                  label: 'Unpair device',
                  variant: TandemButtonVariant.destructive,
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirmUnpair,
                ),
            ],
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return SingleChildScrollView(child: content);
    }

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text(displayName, style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(child: content),
    );
  }
}
