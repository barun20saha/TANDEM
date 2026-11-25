import 'package:flutter/material.dart';
import '../components/banner.dart';
import '../components/buttons.dart';
import '../components/pairing_panel.dart';
import '../models/models.dart';
import '../state/tandem_controller.dart';
import '../theme/tokens.dart';

/// Screen S6: Device Pairing Flow (Section 10.1).
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

  @override
  Widget build(BuildContext context) {
    final PairingPayload? payload = widget.controller.pairingPayload;
    final discoveredUnpaired =
        widget.controller.devices.where((d) => !d.isPaired).toList();

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Pair a device'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload pairing code',
            onPressed: _loadLocalCode,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
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
          if (_loadingCode)
            const Padding(
              padding: EdgeInsets.all(TandemTokens.space_6),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (payload == null)
            BannerNotification(
              variant: BannerVariant.warning,
              message: 'Could not retrieve a local pairing code from the daemon.',
              actionLabel: 'Retry',
              onAction: _loadLocalCode,
            )
          else
            Center(
              child: PairingPanel(
                step: PairingPanelStep.showQR,
                qrPayload: payload.qrPayload,
                shortCode: payload.shortCode,
                remoteDeviceName: payload.name,
              ),
            ),
          const SizedBox(height: TandemTokens.space_5),
          if (discoveredUnpaired.isNotEmpty) ...[
            Text(
              'Nearby discovered devices',
              style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: TandemTokens.space_2),
            for (final peer in discoveredUnpaired)
              Card(
                color: TandemTokens.color_surface,
                child: ListTile(
                  title: Text(peer.name.isNotEmpty ? peer.name : peer.id),
                  subtitle: Text(
                    '${peer.id} ${peer.addresses.isNotEmpty ? "• ${peer.addresses.first}" : ""}',
                    style: TandemTokens.text_xs.copyWith(fontFamily: 'monospace'),
                  ),
                  trailing: TandemButton(
                    label: 'Select',
                    variant: TandemButtonVariant.secondary,
                    onPressed: () {
                      _deviceIdCtrl.text = peer.id;
                      _nameCtrl.text = peer.name;
                      if (peer.addresses.isNotEmpty) {
                        _addrCtrl.text = peer.addresses.first;
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: TandemTokens.space_4),
          ],
          Text(
            'Pair with another device',
            style: TandemTokens.text_md.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: TandemTokens.space_3),
          Container(
            padding: const EdgeInsets.all(TandemTokens.space_4),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _deviceIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Peer Device ID or tandem://pair URI',
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: '6-digit verification code (optional)',
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device label (optional)',
                  ),
                ),
                const SizedBox(height: TandemTokens.space_3),
                TextField(
                  controller: _addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address hint, e.g. tcp://192.168.1.20:22000 (optional)',
                  ),
                ),
                const SizedBox(height: TandemTokens.space_4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TandemButton(
                    label: 'Pair device',
                    variant: TandemButtonVariant.primary,
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _submitPair,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
