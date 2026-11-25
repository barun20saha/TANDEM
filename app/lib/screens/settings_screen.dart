import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

/// Screen S10: Settings & Daemon Runtime Info (Section 10.1).
class SettingsScreen extends StatelessWidget {
  final TandemController controller;
  final bool embedded;

  const SettingsScreen({
    Key? key,
    required this.controller,
    this.embedded = false,
  }) : super(key: key);

  Widget _infoRow(TandemTheme t, String label, String value, {bool mono = true}) {
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
            width: 160.0,
            child: Text(label, style: t.secondaryStyle),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: mono ? t.monoStyle : t.bodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final DaemonStatus? status = controller.status;

    final content = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Settings', style: t.pageTitleStyle)),
              TandemButton(
                label: 'Refresh daemon state',
                variant: TandemButtonVariant.secondary,
                onPressed: () => controller.refreshAll(),
              ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_4),
          Text('Local daemon identity & ports', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Divider(height: 1.0, color: t.border),
          if (status == null)
            Container(
              width: double.infinity,
              color: t.surface,
              padding: const EdgeInsets.all(TandemTokens.space_4),
              child: Text('Daemon status is not available yet.', style: t.bodyStyle),
            )
          else ...[
            _infoRow(t, 'Device name', status.myDeviceName, mono: false),
            _infoRow(t, 'Device ID', status.myDeviceId),
            _infoRow(t, 'Daemon version', status.version),
            _infoRow(
              t,
              'Daemon state',
              status.state.isEmpty
                  ? 'Unknown'
                  : '${status.state[0].toUpperCase()}${status.state.substring(1)}',
              mono: false,
            ),
            _infoRow(t, 'Sync port', '${status.syncPort}'),
            _infoRow(t, 'Discovery port', '${status.discoveryPort}'),
            _infoRow(
              t,
              'Internet reachable',
              status.hasInternet ? 'Yes' : 'No (LAN / offline)',
              mono: false,
            ),
          ],
        ],
      ),
    );

    if (embedded) {
      return SingleChildScrollView(child: content);
    }

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text('Settings', style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(child: content),
    );
  }
}
