import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';

/// Screen S8: System Health Check (Section 10.1).
/// Renders real /health diagnostics from tandemd.
class HealthCheckScreen extends StatefulWidget {
  final TandemController controller;

  const HealthCheckScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  bool _running = false;

  Future<void> _rerunChecks() async {
    setState(() => _running = true);
    await widget.controller.refreshAll();
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final SystemHealth? health = widget.controller.health;
    final DaemonStatus? status = widget.controller.status;

    final List<({String name, String stateLabel, bool ok, String? help})> checks =
        health == null
            ? const []
            : [
                (
                  name: 'Sync engine',
                  stateLabel: health.engineReady ? 'Ready' : 'Not ready',
                  ok: health.engineReady,
                  help: health.engineReady
                      ? null
                      : 'The background sync process is not ready yet.',
                ),
                (
                  name: 'Sync port (TCP/UDP ${status?.syncPort ?? 22000})',
                  stateLabel: health.syncPortOpen ? 'Listening' : 'Closed',
                  ok: health.syncPortOpen,
                  help: health.syncPortOpen
                      ? null
                      : 'No active listener detected on the sync port.',
                ),
                (
                  name: 'Local discovery (UDP ${status?.discoveryPort ?? 21027})',
                  stateLabel: health.discoveryWorks ? 'Listening' : 'Unavailable',
                  ok: health.discoveryWorks,
                  help: health.discoveryWorks
                      ? null
                      : 'Local LAN announcement listener is inactive.',
                ),
                (
                  name: 'Host firewall',
                  stateLabel: health.firewallState,
                  ok: health.firewallState == 'open' ||
                      health.firewallState == 'unknown',
                  help: health.firewallRemediation.isNotEmpty
                      ? health.firewallRemediation
                      : (health.firewallCommand.isNotEmpty
                          ? health.firewallCommand
                          : null),
                ),
                (
                  name: 'Storage health',
                  stateLabel: health.storageOk ? 'OK' : 'Degraded',
                  ok: health.storageOk,
                  help: health.storageOk
                      ? null
                      : 'Storage check reported low free space or permissions error.',
                ),
                (
                  name: 'File watchers',
                  stateLabel:
                      health.inotifyExhausted ? 'Watch limit reached' : 'OK',
                  ok: !health.inotifyExhausted,
                  help: health.inotifyExhausted
                      ? 'Increase fs.inotify.max_user_watches on Linux.'
                      : null,
                ),
              ];

    final hasIssues = checks.any((c) => !c.ok);

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('System Health Check'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (health == null)
            const BannerNotification(
              variant: BannerVariant.warning,
              message:
                  'Health data unavailable: connect to the Tandem daemon to inspect diagnostics.',
            )
          else if (!hasIssues)
            BannerNotification(
              variant: BannerVariant.info,
              message: TandemStrings.get('health.all_clear'),
            )
          else
            const BannerNotification(
              variant: BannerVariant.warning,
              message: 'One or more checks reported an issue below.',
            ),
          const SizedBox(height: TandemTokens.space_4),
          ...checks.map(
            (check) => Container(
              margin: const EdgeInsets.only(bottom: TandemTokens.space_3),
              padding: const EdgeInsets.all(TandemTokens.space_4),
              decoration: BoxDecoration(
                color: TandemTokens.color_surface,
                borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
                border: Border.all(
                  color: check.ok
                      ? TandemTokens.color_border
                      : TandemTokens.color_link_relay,
                  width: check.ok ? 0.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        check.ok ? Icons.check_circle : Icons.warning_amber,
                        size: 20,
                        color: check.ok
                            ? TandemTokens.color_ok
                            : TandemTokens.color_link_relay_text,
                      ),
                      const SizedBox(width: TandemTokens.space_3),
                      Expanded(
                        child: Text(
                          check.name,
                          style: TandemTokens.text_md.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        check.stateLabel,
                        style: TandemTokens.text_sm.copyWith(
                          color: check.ok
                              ? TandemTokens.color_ok
                              : TandemTokens.color_link_relay_text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (check.help != null && check.help!.isNotEmpty) ...[
                    const SizedBox(height: TandemTokens.space_2),
                    Text(
                      check.help!,
                      style: TandemTokens.text_xs.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: TandemTokens.space_4),
          Align(
            alignment: Alignment.centerLeft,
            child: TandemButton(
              label: 'Run diagnostics again',
              variant: TandemButtonVariant.primary,
              isLoading: _running,
              onPressed: _running ? null : _rerunChecks,
            ),
          ),
        ],
      ),
    );
  }
}
