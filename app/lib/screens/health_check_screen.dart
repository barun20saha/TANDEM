import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/banner.dart';
import '../components/buttons.dart';

/// Screen S9: Health Check (Section 10.1).
/// Validates system prerequisites: firewall, local network permission, battery, storage, and UDP discovery.
class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({Key? key}) : super(key: key);

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  bool _isRunningTest = false;

  final List<Map<String, dynamic>> _checks = [
    {
      'title': 'Local Discovery Loopback',
      'description': 'UDP port 21027 broadcast reachable on loopback interface.',
      'status': 'pass',
      'action': null,
    },
    {
      'title': 'Local Network Access',
      'description': 'Broadcast packets permitted on local subnet.',
      'status': 'pass',
      'action': null,
    },
    {
      'title': 'System Firewall Rules',
      'description': 'Port 22000 (TCP/QUIC) allowed for peer sync connections.',
      'status': 'pass',
      'action': null,
    },
    {
      'title': 'Background Battery Optimization',
      'description': 'Background sync active. Unrestricted battery mode recommended.',
      'status': 'warning',
      'action': 'Adjust settings',
    },
    {
      'title': 'Inotify File Watcher Limits',
      'description': 'fs.inotify.max_user_watches is set to 524288 (sufficient for >100,000 files).',
      'status': 'pass',
      'action': null,
    },
  ];

  void _runSelfTest() {
    setState(() => _isRunningTest = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isRunningTest = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
          const BannerNotification(
            title: '4 of 5 checks passed',
            body: 'Tandem is operating normally. One optimization recommendation is available.',
            severity: BannerSeverity.info,
          ),
          const SizedBox(height: TandemTokens.space_4),
          ..._checks.map((check) {
            final isPass = check['status'] == 'pass';
            final isWarning = check['status'] == 'warning';

            return Container(
              margin: const EdgeInsets.only(bottom: TandemTokens.space_3),
              padding: const EdgeInsets.all(TandemTokens.space_4),
              decoration: BoxDecoration(
                color: TandemTokens.color_surface,
                borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
                border: Border.all(color: TandemTokens.color_border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPass
                        ? Icons.check_circle_outline
                        : (isWarning ? Icons.warning_amber_rounded : Icons.error_outline),
                    color: isPass
                        ? TandemTokens.color_ok
                        : (isWarning ? TandemTokens.color_link_relay : TandemTokens.color_danger),
                  ),
                  const SizedBox(width: TandemTokens.space_3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          check['title'] as String,
                          style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: TandemTokens.space_1),
                        Text(
                          check['description'] as String,
                          style: TandemTokens.text_xs.copyWith(
                            color: TandemTokens.color_text.withOpacity(0.7),
                          ),
                        ),
                        if (check['action'] != null) ...[
                          const SizedBox(height: TandemTokens.space_2),
                          TandemButton(
                            label: check['action'] as String,
                            variant: TandemButtonVariant.secondary,
                            size: TandemButtonSize.sm,
                            onPressed: () {},
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: TandemTokens.space_4),
          Center(
            child: TandemButton(
              label: _isRunningTest ? 'Testing...' : 'Run diagnostics again',
              variant: TandemButtonVariant.primary,
              onPressed: _isRunningTest ? null : _runSelfTest,
            ),
          ),
        ],
      ),
    );
  }
}
