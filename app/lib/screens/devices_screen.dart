import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/device_row.dart';
import '../components/link_line.dart';
import '../components/buttons.dart';
import '../components/empty_state.dart';

/// Screen S5: Devices Screen (Section 10.1).
/// Lists this device and all remote paired devices with signature LinkLine state.
class DevicesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final VoidCallback onPairDevice;
  final Function(String deviceId)? onSelectDevice;

  const DevicesScreen({
    Key? key,
    required this.devices,
    required this.onPairDevice,
    this.onSelectDevice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return EmptyState(
        icon: Icons.devices_outlined,
        title: 'No devices yet',
        description: 'Pair a second device to start sending and syncing.',
        actionLabel: 'Pair device',
        onAction: onPairDevice,
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Devices'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TandemTokens.space_3),
            child: TandemButton(
              label: 'Pair device',
              variant: TandemButtonVariant.primary,
              onPressed: onPairDevice,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final d = devices[index];
          final linkStr = d['linkState'] as String? ?? 'direct-local';
          LinkLineState linkState = LinkLineState.directLocal;
          if (linkStr == 'direct-internet') linkState = LinkLineState.directInternet;
          if (linkStr == 'relayed') linkState = LinkLineState.relayed;
          if (linkStr == 'connecting') linkState = LinkLineState.connecting;
          if (linkStr == 'offline') linkState = LinkLineState.offline;

          return DeviceRow(
            deviceId: d['id'] ?? '',
            name: d['name'] ?? '',
            isThisDevice: d['isThisDevice'] == true,
            linkState: linkState,
            lastSeen: d['lastSeen'] ?? 'Just now',
            onTap: () => onSelectDevice?.call(d['id'] ?? ''),
          );
        },
      ),
    );
  }
}
