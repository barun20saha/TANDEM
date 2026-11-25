import 'package:flutter/material.dart';
import '../components/buttons.dart';
import '../components/device_row.dart';
import '../components/empty_state.dart';
import '../components/link_line.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../theme/tandem_theme.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import 'no_internet_helper_screen.dart';

/// Screen S5: Devices Screen (Section 10.1).
/// Renders local daemon identity, paired peers with live LinkLine, and discovered nearby devices.
class DevicesScreen extends StatelessWidget {
  final DaemonStatus? status;
  final List<TandemDevice> devices;
  final VoidCallback onPairDevice;
  final Function(TandemDevice device)? onSelectDevice;
  final String? selectedDeviceId;
  final bool embedded;

  const DevicesScreen({
    Key? key,
    required this.status,
    required this.devices,
    required this.onPairDevice,
    this.onSelectDevice,
    this.selectedDeviceId,
    this.embedded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = TandemTheme.of(context);
    final paired = devices.where((d) => d.isPaired).toList();
    final nearby = devices.where((d) => !d.isPaired).toList();

    final body = WorkspacePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text('Devices', style: t.pageTitleStyle),
              ),
              Wrap(
                spacing: TandemTokens.space_2,
                runSpacing: TandemTokens.space_2,
                children: [
                  TandemButton(
                    label: 'Offline transfer guide',
                    variant: TandemButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NoInternetHelperScreen(),
                        ),
                      );
                    },
                  ),
                  TandemButton(
                    label: 'Pair device',
                    variant: TandemButtonVariant.primary,
                    onPressed: onPairDevice,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: TandemTokens.space_4),
          if (status != null) ...[
            Text('This device', style: t.captionStyle),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            DeviceRow(
              deviceId: status!.myDeviceId,
              name: status!.myDeviceName,
              isThisDevice: true,
              linkState: LinkLineState.directLocal,
              lastSeen:
                  'Sync ${status!.syncPort} / Discovery ${status!.discoveryPort}',
            ),
            const SizedBox(height: TandemTokens.space_5),
          ],
          if (paired.isEmpty && nearby.isEmpty)
            EmptyState(
              icon: Icons.devices_outlined,
              title: 'No paired devices',
              description: TandemStrings.get('devices.empty'),
              actionLabel: 'Pair device',
              onAction: onPairDevice,
            ),
          if (paired.isNotEmpty) ...[
            Text('Paired devices', style: t.captionStyle),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            ...paired.map(
              (d) => DeviceRow(
                deviceId: d.id,
                name: d.name.isNotEmpty ? d.name : d.id,
                isThisDevice: false,
                selected: d.id == selectedDeviceId,
                linkState: parseLinkState(d.linkState),
                syncState: (d.uploadRateBytesPerSec > 0 ||
                        d.downloadRateBytesPerSec > 0)
                    ? DeviceSyncState.syncing
                    : DeviceSyncState.upToDate,
                lastSeen: formatLastSeen(d.lastSeen, fallback: 'Paired'),
                onTap: () => onSelectDevice?.call(d),
              ),
            ),
            const SizedBox(height: TandemTokens.space_5),
          ],
          if (nearby.isNotEmpty) ...[
            Text('Nearby discovered (not paired)', style: t.captionStyle),
            const SizedBox(height: TandemTokens.space_2),
            Divider(height: 1.0, color: t.border),
            ...nearby.map(
              (d) => DeviceRow(
                deviceId: d.id,
                name: d.name.isNotEmpty ? d.name : d.id,
                isThisDevice: false,
                linkState: parseLinkState(d.linkState),
                syncState: DeviceSyncState.offline,
                lastSeen: d.addresses.isNotEmpty
                    ? d.addresses.first
                    : 'Local announcement',
                onTap: () => onSelectDevice?.call(d),
              ),
            ),
          ],
        ],
      ),
    );

    if (embedded) {
      return SingleChildScrollView(child: body);
    }

    return Scaffold(
      backgroundColor: t.ground,
      body: SingleChildScrollView(child: body),
    );
  }
}
