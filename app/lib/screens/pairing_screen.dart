import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/pairing_panel.dart';

/// Screen S7: Pairing Screen (Section 10.1 & Section 6).
/// Provides full QR presentation, camera scanner, and 6-digit confirmation code.
class PairingScreen extends StatefulWidget {
  final VoidCallback? onPairingComplete;

  const PairingScreen({
    Key? key,
    this.onPairingComplete,
  }) : super(key: key);

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  PairingPanelStep _step = PairingPanelStep.showQR;
  final String _qrPayload = 'tandem://pair?v=1&id=A1B2C3D4&token=s3cr3t&name=Barun-Laptop';
  final String _shortCode = '849 201';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Pair Device'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_step == PairingPanelStep.showQR ? Icons.qr_code_scanner : Icons.qr_code),
            tooltip: _step == PairingPanelStep.showQR ? 'Scan QR code' : 'Show my QR code',
            onPressed: () {
              setState(() {
                _step = _step == PairingPanelStep.showQR
                    ? PairingPanelStep.scanQR
                    : PairingPanelStep.showQR;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TandemTokens.space_5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480.0),
            child: PairingPanel(
              step: _step,
              qrPayload: _qrPayload,
              shortCode: _shortCode,
              remoteDeviceName: 'Pixel 9 Pro',
              onConfirmMatch: () {
                widget.onPairingComplete?.call();
                Navigator.of(context).pop();
              },
              onRejectMatch: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
