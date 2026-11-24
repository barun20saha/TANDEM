import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/link_line.dart';
import '../components/buttons.dart';
import '../components/device_row.dart';
import '../components/folder_row.dart';
import '../components/transfer_row.dart';
import '../components/banner.dart';
import '../components/pairing_panel.dart';
import '../components/empty_state.dart';

/// ComponentGalleryScreen: Renders all design system components in all states (Phase 3 Done When).
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tandem Component Gallery'),
        backgroundColor: TandemTokens.color_surface,
      ),
      backgroundColor: TandemTokens.color_ground,
      body: ListView(
        padding: const EdgeInsets.all(TandemTokens.space_5),
        children: [
          _buildSection('1. LinkLine States (Section 5.1 & 8.3)', [
            const LinkLine(state: LinkLineState.directLocal),
            const SizedBox(height: TandemTokens.space_3),
            const LinkLine(state: LinkLineState.directInternet),
            const SizedBox(height: TandemTokens.space_3),
            const LinkLine(state: LinkLineState.relayed),
            const SizedBox(height: TandemTokens.space_3),
            const LinkLine(state: LinkLineState.connecting),
            const SizedBox(height: TandemTokens.space_3),
            const LinkLine(state: LinkLineState.offline),
          ]),

          _buildSection('2. Buttons (Variants & States)', [
            Wrap(
              spacing: TandemTokens.space_3,
              runSpacing: TandemTokens.space_3,
              children: [
                TandemButton(label: 'Primary MD', onPressed: () {}),
                TandemButton(label: 'Primary LG', size: TandemButtonSize.lg, onPressed: () {}),
                TandemButton(label: 'Secondary', variant: TandemButtonVariant.secondary, onPressed: () {}),
                TandemButton(label: 'Quiet', variant: TandemButtonVariant.quiet, onPressed: () {}),
                TandemButton(label: 'Destructive', variant: TandemButtonVariant.destructive, onPressed: () {}),
                const TandemButton(label: 'Disabled', onPressed: null),
                TandemButton(label: 'Loading', isLoading: true, onPressed: () {}),
              ],
            ),
          ]),

          _buildSection('3. DeviceRow (Local & Remote States)', [
            const DeviceRow(
              deviceId: 'LOCAL-1',
              name: 'Barun’s Framework Laptop',
              isThisDevice: true,
            ),
            const DeviceRow(
              deviceId: 'REMOTE-1',
              name: 'Pixel 9 Pro (Wi-Fi LAN)',
              linkState: LinkLineState.directLocal,
              syncState: DeviceSyncState.upToDate,
              lastSeen: 'Active now',
            ),
            const DeviceRow(
              deviceId: 'REMOTE-2',
              name: 'Home Desktop Server (Internet)',
              linkState: LinkLineState.directInternet,
              syncState: DeviceSyncState.syncing,
              lastSeen: '10 min ago',
            ),
            const DeviceRow(
              deviceId: 'REMOTE-3',
              name: 'Office Mac (Relayed)',
              linkState: LinkLineState.relayed,
              syncState: DeviceSyncState.upToDate,
              lastSeen: '1 hr ago',
            ),
          ]),

          _buildSection('4. FolderRow (Types & States)', [
            const FolderRow(
              label: 'Work Documents',
              path: '/home/barun/Documents/Work',
              type: FolderType.sendReceive,
              state: FolderSyncState.upToDate,
              formattedSize: '1.4 GB',
              deviceCount: 3,
            ),
            const FolderRow(
              label: 'Camera Backup',
              path: '/sdcard/DCIM/Camera',
              type: FolderType.sendOnly,
              state: FolderSyncState.syncing,
              formattedSize: '14.2 GB',
              deviceCount: 2,
            ),
            const FolderRow(
              label: 'Shared Media',
              path: '/home/barun/Media',
              type: FolderType.receiveOnly,
              state: FolderSyncState.paused,
              formattedSize: '512 MB',
              deviceCount: 1,
            ),
          ]),

          _buildSection('5. TransferRow', [
            const TransferRow(
              fileName: 'DSC_0982.RAW',
              state: TransferState.sending,
              progress: 0.65,
              speedText: '24.5 MB/s',
              timeLeftText: '4s left',
              interfaceUsed: 'Direct Wi-Fi',
            ),
            const TransferRow(
              fileName: 'backup_archive.tar.gz',
              state: TransferState.done,
              progress: 1.0,
            ),
            TransferRow(
              fileName: 'video_4k_sample.mp4',
              state: TransferState.failed,
              failureReason: 'Connection timed out on guest network',
              onRetry: () {},
            ),
          ]),

          _buildSection('6. Banners', [
            BannerNotification(
              message: 'Windows Defender Firewall is blocking incoming connections.',
              variant: BannerVariant.warning,
              actionLabel: 'Allow Tandem',
              onAction: () {},
            ),
            BannerNotification(
              message: 'Storage limit reached on destination device.',
              variant: BannerVariant.error,
              actionLabel: 'Manage Storage',
              onAction: () {},
            ),
          ]),

          _buildSection('7. PairingPanel', [
            PairingPanel(
              step: PairingPanelStep.confirmMatch,
              qrPayload: 'tandem://pair?id=TEST&name=Demo',
              shortCode: '849-210',
              onConfirmMatch: () {},
              onRejectMatch: () {},
            ),
          ]),

          _buildSection('8. EmptyState', [
            EmptyState(
              icon: Icons.sync_disabled,
              title: 'No synced folders yet',
              description: 'Choose a folder to keep the same on all your devices.',
              actionLabel: 'Choose folder',
              onAction: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: TandemTokens.space_6),
      decoration: BoxDecoration(
        color: TandemTokens.color_surface,
        borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
        border: Border.all(color: TandemTokens.color_border, width: 0.5),
      ),
      padding: const EdgeInsets.all(TandemTokens.space_4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TandemTokens.text_lg.copyWith(
              fontFamily: 'Familjen Grotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(height: TandemTokens.space_4, color: TandemTokens.color_border),
          ...children,
        ],
      ),
    );
  }
}
