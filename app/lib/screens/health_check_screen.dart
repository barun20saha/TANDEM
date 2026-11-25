import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

/// Screen S9: System Health Check (Section 10.1).
/// Renders real /health diagnostics from tandemd.
class HealthCheckScreen extends StatefulWidget {
  final TandemController controller;
  final bool embedded;

  const HealthCheckScreen({
    Key? key,
    required this.controller,
    this.embedded = false,
  }) : super(key: key);

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

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String? _firewallHelp(SystemHealth h) {
    final parts = <String>[
      if (h.firewallRemediation.isNotEmpty) h.firewallRemediation,
      if (h.firewallCommand.isNotEmpty) h.firewallCommand,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
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
                  stateLabel: _capitalize(health.firewallState),
                  ok: health.firewallState == 'open' ||
                      health.firewallState == 'unknown',
                  help: _firewallHelp(health),
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

    final body = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('System Health Check', style: t.pageTitleStyle),
              ),
              TandemButton(
                label: 'Run diagnostics again',
                variant: TandemButtonVariant.primary,
                isLoading: _running,
                onPressed: _running ? null : _rerunChecks,
              ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_4),
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
          if (checks.isNotEmpty) Divider(height: 1.0, color: t.border),
          ...checks.map(
            (check) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TandemTokens.space_4,
                vertical: TandemTokens.space_3,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        check.ok ? Icons.check_circle_outline : Icons.warning_amber,
                        size: 18.0,
                        color: check.ok ? t.ok : t.linkRelayText,
                      ),
                      const SizedBox(width: TandemTokens.space_3),
                      Expanded(
                        child: Text(
                          check.name,
                          style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        check.stateLabel,
                        style: TandemTokens.text_sm.copyWith(
                          color: check.ok ? t.ok : t.linkRelayText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (check.help != null && check.help!.isNotEmpty) ...[
                    const SizedBox(height: TandemTokens.space_2),
                    SelectableText(
                      check.help!,
                      style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return SingleChildScrollView(child: body);
    }

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text('System Health Check', style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(child: body),
    );
  }
}
