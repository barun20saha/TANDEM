import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/empty_state.dart';
import '../components/transfer_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S4: Send Screen (Section 10.1 & DECISION D2).
class SendScreen extends StatefulWidget {
  final List<TandemDevice> pairedDevices;
  final List<SendSession> sessions;
  final Future<void> Function(String targetDeviceId, List<String> filePaths) onInitiateSend;

  const SendScreen({
    Key? key,
    required this.pairedDevices,
    required this.sessions,
    required this.onInitiateSend,
  }) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _pathsCtrl = TextEditingController();
  String? _selectedDeviceId;
  bool _sending = false;
  String? _errorText;

  @override
  void dispose() {
    _pathsCtrl.dispose();
    super.dispose();
  }

  TransferState _parseState(String s) {
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

  Future<void> _showSendDialog() async {
    if (widget.pairedDevices.isEmpty) {
      setState(() => _errorText = 'Pair a device before sending files.');
      return;
    }
    _selectedDeviceId ??= widget.pairedDevices.first.id;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: TandemTokens.color_surface,
          title: const Text('Send files'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedDeviceId,
                  decoration: const InputDecoration(labelText: 'Target device'),
                  items: widget.pairedDevices
                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => _selectedDeviceId = v),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TextField(
                  controller: _pathsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'File paths (one per line)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TandemButton(
              label: 'Cancel',
              variant: TandemButtonVariant.quiet,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TandemButton(
              label: 'Send files',
              isLoading: _sending,
              onPressed: () async {
                final paths = _pathsCtrl.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (paths.isEmpty || _selectedDeviceId == null) return;
                setState(() {
                  _sending = true;
                  _errorText = null;
                });
                try {
                  await widget.onInitiateSend(_selectedDeviceId!, paths);
                  _pathsCtrl.clear();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  setState(() => _errorText = e.toString());
                } finally {
                  if (mounted) setState(() => _sending = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty && _errorText == null) {
      return EmptyState(
        icon: Icons.send_outlined,
        title: 'Nothing to send yet',
        description: TandemStrings.get('send.empty'),
        actionLabel: 'Send files',
        onAction: _showSendDialog,
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Send'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: 'Send files',
              variant: TandemButtonVariant.primary,
              onPressed: _showSendDialog,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TandemTokens.space_3),
              child: Text(
                _errorText!,
                style: TandemTokens.text_sm.copyWith(color: TandemTokens.color_danger),
              ),
            ),
          ...widget.sessions.map(
            (s) => TransferRow(
              fileName: '${s.sessionId} (${s.filesSent}/${s.totalFiles} files)',
              state: _parseState(s.state),
              progress: s.progress,
              speedText: formatSpeed(s.speedBytesPerSec),
              timeLeftText: s.state == 'completed' ? 'Complete' : formatBytes(s.totalBytes - s.bytesSent),
              interfaceUsed: s.interfaceUsed,
            ),
          ),
        ],
      ),
    );
  }
}
