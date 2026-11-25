import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/device_row.dart';
import '../components/empty_state.dart';
import '../components/link_line.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// Screen S5: Devices Screen (Section 10.1).
/// Renders real local device identity + paired/discovered devices from tandemd.
class DevicesScreen extends StatelessWidget {
  final DaemonStatus? status;
  final List<TandemDevice> devices;
  final VoidCallback onPairDevice;
  final Function(TandemDevice device)? onSelectDevice;

  const DevicesScreen({
    Key? key,
    required this.status,
    required this.devices,
    required this.onPairDevice,
    this.onSelectDevice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        children: [
          if (status != null)
            DeviceRow(
              deviceId: status!.myDeviceId,
              name: status!.myDeviceName,
              isThisDevice: true,
              linkState: LinkLineState.directLocal,
              lastSeen: 'This device',
            ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TandemTokens.space_6),
              child: EmptyState(
                icon: Icons.devices_outlined,
                title: 'No paired devices',
                description: TandemStrings.get('devices.empty'),
                actionLabel: 'Pair device',
                onAction: onPairDevice,
              ),
            )
          else
            ...devices.map(
              (d) => DeviceRow(
                deviceId: d.id,
                name: d.name.isNotEmpty ? d.name : d.id,
                isThisDevice: false,
                linkState: parseLinkState(d.linkState),
                syncState: (d.uploadRateBytesPerSec > 0 || d.downloadRateBytesPerSec > 0)
                    ? DeviceSyncState.syncing
                    : DeviceSyncState.upToDate,
                lastSeen: d.isPaired
                    ? (d.lastSeen.isNotEmpty ? d.lastSeen : 'Paired')
                    : 'Nearby (not paired)',
                onTap: () => onSelectDevice?.call(d),
              ),
            ),
        ],
      ),
    );
  }
}
