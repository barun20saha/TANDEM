import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/empty_state.dart';
import '../components/transfer_row.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S4: Send Screen (Section 10.1 & DECISION D2).
/// Inline one-step file send composer + real session queue.
class SendScreen extends StatefulWidget {
  final List<TandemDevice> pairedDevices;
  final List<SendSession> sessions;
  final Future<void> Function(String targetDeviceId, List<String> filePaths) onInitiateSend;
  final bool embedded;

  const SendScreen({
    Key? key,
    required this.pairedDevices,
    required this.sessions,
    required this.onInitiateSend,
    this.embedded = false,
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
  void initState() {
    super.initState();
    if (widget.pairedDevices.isNotEmpty) {
      _selectedDeviceId = widget.pairedDevices.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant SendScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDeviceId == null && widget.pairedDevices.isNotEmpty) {
      _selectedDeviceId = widget.pairedDevices.first.id;
    }
  }

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

  Future<void> _submitSend() async {
    final targetId = _selectedDeviceId;
    if (targetId == null || widget.pairedDevices.isEmpty) {
      setState(() => _errorText = 'Pair a device before sending files.');
      return;
    }
    final paths = _pathsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      setState(() => _errorText = 'Enter at least one file path to send.');
      return;
    }
    setState(() {
      _sending = true;
      _errorText = null;
    });
    try {
      await widget.onInitiateSend(targetId, paths);
      _pathsCtrl.clear();
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _resolvePeerName(String deviceId) {
    for (final d in widget.pairedDevices) {
      if (d.id == deviceId && d.name.isNotEmpty) {
        return d.name;
      }
    }
    return deviceId;
  }

  InputDecoration _inputDecoration(
    TandemTheme t, {
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: t.secondaryStyle,
      hintStyle: t.captionStyle,
      filled: true,
      fillColor: t.ground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TandemTokens.space_3,
        vertical: TandemTokens.space_3,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        borderSide: BorderSide(color: t.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TandemTokens.radius_control),
        borderSide: BorderSide(color: t.linkDirect, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);

    final body = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send files', style: t.pageTitleStyle),
          const SizedBox(height: TandemTokens.space_1),
          Text(
            'Send a one-time batch to a paired device without creating a synced folder.',
            style: t.secondaryStyle,
          ),
          const SizedBox(height: TandemTokens.space_4),
          if (_errorText != null) ...[
            BannerNotification(
              variant: BannerVariant.error,
              message: _errorText!,
            ),
            const SizedBox(height: TandemTokens.space_3),
          ],
          if (widget.pairedDevices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(TandemTokens.space_4),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
                border: Border.all(color: t.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedDeviceId,
                    dropdownColor: t.surface,
                    style: t.bodyStyle,
                    decoration: _inputDecoration(t, labelText: 'Recipient device'),
                    items: widget.pairedDevices
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.name.isNotEmpty ? d.name : d.id),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDeviceId = v),
                  ),
                  const SizedBox(height: TandemTokens.space_3),
                  TextField(
                    controller: _pathsCtrl,
                    maxLines: 3,
                    style: t.monoStyle,
                    decoration: _inputDecoration(
                      t,
                      labelText: 'File paths (one per line)',
                      hintText: '/path/to/photo.jpg',
                    ),
                  ),
                  const SizedBox(height: TandemTokens.space_4),
                  TandemButton(
                    label: 'Send files',
                    variant: TandemButtonVariant.primary,
                    isLoading: _sending,
                    onPressed: _sending ? null : _submitSend,
                  ),
                ],
              ),
            ),
          const SizedBox(height: TandemTokens.space_5),
          Text('Transfers', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          if (widget.sessions.isEmpty)
            EmptyState(
              icon: Icons.send_outlined,
              title: 'Nothing to send yet',
              description: TandemStrings.get('send.empty'),
              actionLabel: widget.pairedDevices.isEmpty ? null : 'Send files',
              onAction: widget.pairedDevices.isEmpty ? null : _submitSend,
            )
          else ...[
            Divider(height: 1.0, color: t.border),
            ...widget.sessions.map(
              (s) => TransferRow(
                fileName:
                    '${s.filesSent} of ${s.totalFiles} files to ${_resolvePeerName(s.targetDeviceId)}',
                state: _parseState(s.state),
                progress: s.progress,
                speedText: formatSpeed(s.speedBytesPerSec),
                timeLeftText: s.state == 'completed'
                    ? 'Complete'
                    : formatBytes(s.totalBytes - s.bytesSent),
                interfaceUsed: s.interfaceUsed,
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return SingleChildScrollView(child: body);
    }

    return Scaffold(
      backgroundColor: t.ground,
      body: SingleChildScrollView(child: body),
    );
  }
}
