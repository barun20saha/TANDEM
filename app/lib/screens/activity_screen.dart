import 'package:flutter/material.dart';
import '../components/empty_state.dart';
import '../components/transfer_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S9: Activity Log (Section 10.1).
/// Shows only real send sessions and live daemon events recorded in this session.
class ActivityScreen extends StatelessWidget {
  final TandemController controller;

  const ActivityScreen({Key? key, required this.controller}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sendSessions;
    final events = controller.recentEvents;

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
      ),
      body: (sessions.isEmpty && events.isEmpty)
          ? EmptyState(
              icon: Icons.history,
              title: 'No activity yet',
              description: TandemStrings.get('activity.empty'),
            )
          : ListView(
              padding: const EdgeInsets.all(TandemTokens.space_4),
              children: [
                if (sessions.isNotEmpty) ...[
                  Text(
                    'Send transfers',
                    style: TandemTokens.text_md.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: TandemTokens.space_2),
                  for (final SendSession s in sessions)
                    TransferRow(
                      fileName: '${s.totalFiles} file(s) -> ${s.targetDeviceId}',
                      state: _parseSendState(s.state),
                      progress: s.progress,
                      speedText: formatSpeed(s.speedBytesPerSec),
                      timeLeftText: s.state == 'completed'
                          ? 'Done (${formatBytes(s.totalBytes)})'
                          : formatBytes(s.totalBytes),
                      interfaceUsed: s.interfaceUsed,
                    ),
                  const SizedBox(height: TandemTokens.space_4),
                ],
                if (events.isNotEmpty) ...[
                  Text(
                    'Recent daemon events',
                    style: TandemTokens.text_md.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: TandemTokens.space_2),
                  for (final DaemonEvent ev in events.reversed)
                    Container(
                      margin: const EdgeInsets.only(bottom: TandemTokens.space_2),
                      padding: const EdgeInsets.all(TandemTokens.space_3),
                      decoration: BoxDecoration(
                        color: TandemTokens.color_surface,
                        borderRadius:
                            BorderRadius.circular(TandemTokens.radius_panel),
                        border: Border.all(
                          color: TandemTokens.color_border,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ev.event,
                              style: TandemTokens.text_md,
                            ),
                          ),
                          if (ev.raw['time'] != null)
                            Text(
                              ev.raw['time'].toString(),
                              style: TandemTokens.text_sm.copyWith(
                                color: TandemTokens.color_text.withAlpha(153),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
