import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/empty_state.dart';
import '../components/transfer_row.dart';
import '../components/buttons.dart';

/// Screen S4: Send Screen (Section 10.1 & DECISION D2).
/// Ephemeral one-off file transmission to nearby paired devices.
class SendScreen extends StatelessWidget {
  final List<String> selectedFiles;
  final List<Map<String, dynamic>> activeTransfers;
  final VoidCallback onPickFiles;
  final Function(String targetDeviceId)? onSendToDevice;

  const SendScreen({
    Key? key,
    required this.selectedFiles,
    required this.activeTransfers,
    required this.onPickFiles,
    this.onSendToDevice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedFiles.isEmpty && activeTransfers.isEmpty) {
      return EmptyState(
        icon: Icons.send_outlined,
        title: 'Nothing to send yet',
        description: 'Choose files or a folder, then pick a nearby device.',
        actionLabel: 'Choose files',
        onAction: onPickFiles,
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Send Files'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: 'Choose more',
              variant: TandemButtonVariant.secondary,
              onPressed: onPickFiles,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_4),
        children: [
          if (activeTransfers.isNotEmpty) ...[
            Text(
              'Active Transfers',
              style: TandemTokens.text_lg.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: TandemTokens.space_2),
            ...activeTransfers.map((t) => TransferRow(
                  fileName: t['fileName'] ?? '',
                  state: TransferState.sending,
                  progress: t['progress'] ?? 0.5,
                  speedText: t['speedText'] ?? '18 MB/s',
                  timeLeftText: t['timeLeftText'] ?? '3s left',
                  interfaceUsed: t['interface'] ?? 'Wi-Fi',
                )),
            const SizedBox(height: TandemTokens.space_5),
          ],

          if (selectedFiles.isNotEmpty) ...[
            Text(
              'Selected Files (${selectedFiles.length})',
              style: TandemTokens.text_lg.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: TandemTokens.space_2),
            Container(
              decoration: BoxDecoration(
                color: TandemTokens.color_surface,
                borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
                border: Border.all(color: TandemTokens.color_border, width: 0.5),
              ),
              child: Column(
                children: selectedFiles
                    .map((f) => ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(f, style: TandemTokens.text_sm),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
