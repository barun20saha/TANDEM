import 'package:flutter/material.dart';
import '../components/empty_state.dart';
import '../components/transfer_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S11: Activity Log (Section 10.1).
/// Shows only real send sessions and live daemon events recorded in this session.
class ActivityScreen extends StatelessWidget {
  final TandemController controller;
  final bool embedded;

  const ActivityScreen({
    Key? key,
    required this.controller,
    this.embedded = false,
  }) : super(key: key);

  TransferState _parseSendState(String s) {
    switch (s) {
      case 'completed':
        return TransferState.done;
      case 'failed':
      case 'cancelled':
        return TransferState.failed;
      case 'queued':
        return TransferState.queued;
      default:
        return TransferState.sending;
    }
  }

  String _resolvePeerName(String deviceId) {
    for (final d in controller.devices) {
      if (d.id == deviceId && d.name.isNotEmpty) {
        return d.name;
      }
    }
    return deviceId;
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final sessions = controller.sendSessions;
    final events = controller.recentEvents;

    final content = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Log', style: t.pageTitleStyle),
          const SizedBox(height: TandemTokens.space_4),
          if (sessions.isEmpty && events.isEmpty)
            EmptyState(
              icon: Icons.history,
              title: 'No activity yet',
              description: TandemStrings.get('activity.empty'),
            )
          else ...[
            if (sessions.isNotEmpty) ...[
              Text('Send transfers', style: t.sectionTitleStyle),
              const SizedBox(height: TandemTokens.space_2),
              Divider(height: 1.0, color: t.border),
              for (final SendSession s in sessions)
                TransferRow(
                  fileName:
                      '${s.totalFiles} file${s.totalFiles == 1 ? '' : 's'} to ${_resolvePeerName(s.targetDeviceId)}',
                  state: _parseSendState(s.state),
                  progress: s.progress,
                  speedText: formatSpeed(s.speedBytesPerSec),
                  timeLeftText: s.state == 'completed'
                      ? 'Done (${formatBytes(s.totalBytes)})'
                      : formatBytes(s.totalBytes),
                  interfaceUsed: s.interfaceUsed,
                ),
              const SizedBox(height: TandemTokens.space_5),
            ],
            if (events.isNotEmpty) ...[
              Text('Recent daemon events', style: t.sectionTitleStyle),
              const SizedBox(height: TandemTokens.space_2),
              Divider(height: 1.0, color: t.border),
              for (final DaemonEvent ev in events.reversed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TandemTokens.space_4,
                    vertical: TandemTokens.space_3,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(ev.event, style: t.bodyStyle)),
                      if (ev.raw['time'] != null)
                        Text(
                          ev.raw['time'].toString(),
                          style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                        ),
                    ],
                  ),
                ),
            ],
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
        title: Text('Activity Log', style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(child: content),
    );
  }
}
