import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/pairing_panel.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';

/// Screen S7: Device Pairing Flow (Section 10.1).
/// Fetches real local pairing payload from tandemd and submits peer Device ID + code.
class PairingScreen extends StatefulWidget {
  final TandemController controller;

  const PairingScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _deviceIdCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addrCtrl = TextEditingController();

  bool _loadingCode = true;
  bool _submitting = false;
  String? _errorText;
  String? _successText;

  @override
  void initState() {
    super.initState();
    _loadLocalCode();
  }

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalCode() async {
    setState(() {
      _loadingCode = true;
      _errorText = null;
    });
    await widget.controller.loadPairingCode();
    if (!mounted) return;
    setState(() => _loadingCode = false);
  }

  Future<void> _submitPair() async {
    final rawInput = _deviceIdCtrl.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _errorText = 'Enter the peer Device ID or tandem://pair URI.');
      return;
    }

    String targetId = rawInput;
    String code = _codeCtrl.text.trim();
    String peerName = _nameCtrl.text.trim();
    final addrHint = _addrCtrl.text.trim();

    if (rawInput.startsWith('tandem://')) {
      final uri = Uri.tryParse(rawInput);
      final parsedId = uri?.queryParameters['id'] ?? '';
      if (parsedId.isEmpty) {
        setState(() => _errorText = 'Pairing URI does not include a device id.');
        return;
      }
      targetId = parsedId;
      if (code.isEmpty) {
        code = uri?.queryParameters['code'] ?? '';
      }
      if (peerName.isEmpty) {
        peerName = uri?.queryParameters['name'] ?? '';
      }
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _successText = null;
    });

    try {
      if (code.isNotEmpty) {
        final matched = await widget.controller.pairByCode(
          targetDeviceId: targetId,
          confirmedCode: code,
          name: peerName.isEmpty ? null : peerName,
          addressHint: addrHint.isEmpty ? null : addrHint,
        );
        if (!mounted) return;
        if (!matched) {
          setState(() {
            _submitting = false;
            _errorText = 'Pairing confirmation failed.';
          });
          return;
        }
      } else {
        await widget.controller.pairDevice(
          deviceId: targetId,
          name: peerName.isEmpty ? targetId : peerName,
          addressHint: addrHint.isEmpty ? null : addrHint,
        );
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _successText = 'Device paired.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = e.toString();
      });
    }
  }

  InputDecoration _inputDecoration(TandemTheme t, String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: t.secondaryStyle,
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
    final PairingPayload? payload = widget.controller.pairingPayload;
    final discoveredUnpaired =
        widget.controller.devices.where((d) => !d.isPaired).toList();

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingCode)
          Padding(
            padding: const EdgeInsets.all(TandemTokens.space_5),
            child: CircularProgressIndicator(color: t.linkDirect),
          )
        else if (payload == null)
          BannerNotification(
            variant: BannerVariant.warning,
            message: 'Could not retrieve a local pairing code from the daemon.',
            actionLabel: 'Retry',
            onAction: _loadLocalCode,
          )
        else
          PairingPanel(
            step: PairingPanelStep.showQR,
            qrPayload: payload.qrPayload,
            shortCode: payload.shortCode,
            remoteDeviceName: payload.name,
          ),
        if (discoveredUnpaired.isNotEmpty) ...[
          const SizedBox(height: TandemTokens.space_5),
          Text('Nearby discovered devices', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_2),
          Divider(height: 1.0, color: t.border),
          for (final peer in discoveredUnpaired)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TandemTokens.space_3,
                vertical: TandemTokens.space_3,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peer.name.isNotEmpty ? peer.name : peer.id,
                          style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          peer.addresses.isNotEmpty
                              ? peer.addresses.first
                              : peer.id,
                          style: t.monoStyle.copyWith(fontSize: 12.0, color: t.mutedText),
                        ),
                      ],
                    ),
                  ),
                  TandemButton(
                    label: 'Use peer',
                    variant: TandemButtonVariant.secondary,
                    onPressed: () {
                      _deviceIdCtrl.text = peer.id;
                      _nameCtrl.text = peer.name;
                      if (peer.addresses.isNotEmpty) {
                        _addrCtrl.text = peer.addresses.first;
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    final rightColumn = Container(
      padding: const EdgeInsets.all(TandemTokens.space_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect to peer', style: t.sectionTitleStyle),
          const SizedBox(height: TandemTokens.space_1),
          Text(
            'Enter the second device identifier and optional 6-digit code.',
            style: t.secondaryStyle,
          ),
          const SizedBox(height: TandemTokens.space_3),
          TextField(
            controller: _deviceIdCtrl,
            style: t.monoStyle,
            decoration: _inputDecoration(
              t,
              'Peer Device ID or tandem://pair URI',
            ),
          ),
          const SizedBox(height: TandemTokens.space_3),
          TextField(
            controller: _codeCtrl,
            style: t.monoStyle,
            decoration: _inputDecoration(
              t,
              '6-digit verification code (optional)',
            ),
          ),
          const SizedBox(height: TandemTokens.space_3),
          TextField(
            controller: _nameCtrl,
            style: t.bodyStyle,
            decoration: _inputDecoration(t, 'Device label (optional)'),
          ),
          const SizedBox(height: TandemTokens.space_3),
          TextField(
            controller: _addrCtrl,
            style: t.monoStyle,
            decoration: _inputDecoration(
              t,
              'Address hint (optional, e.g. tcp://192.168.1.20:22000)',
            ),
          ),
          const SizedBox(height: TandemTokens.space_4),
          TandemButton(
            label: 'Pair device',
            variant: TandemButtonVariant.primary,
            isLoading: _submitting,
            onPressed: _submitting ? null : _submitPair,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: t.ground,
      appBar: AppBar(
        title: Text('Pair a device', style: t.sectionTitleStyle),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload pairing code',
            onPressed: _loadLocalCode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: WorkspacePane(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorText != null) ...[
                BannerNotification(
                  variant: BannerVariant.error,
                  message: _errorText!,
                ),
                const SizedBox(height: TandemTokens.space_3),
              ],
              if (_successText != null) ...[
                BannerNotification(
                  variant: BannerVariant.info,
                  message: _successText!,
                ),
                const SizedBox(height: TandemTokens.space_3),
              ],
              if (t.isTabletOrLarger)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftColumn),
                    const SizedBox(width: TandemTokens.space_5),
                    Expanded(flex: 6, child: rightColumn),
                  ],
                )
              else ...[
                leftColumn,
                const SizedBox(height: TandemTokens.space_5),
                rightColumn,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
