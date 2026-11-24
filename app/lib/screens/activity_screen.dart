import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../components/transfer_row.dart';
import '../components/empty_state.dart';

/// Screen S11: Activity (Section 10.1).
/// Recent transfers, completed syncs, recovered trash items, and errors.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> activities = [
      {
        'fileName': 'project_specs_v2.pdf',
        'progress': 1.0,
        'speedText': '32.1 MB/s',
        'timeLeftText': 'Completed 5m ago',
        'interface': 'Direct Wi-Fi',
      },
      {
        'fileName': 'IMG_20261124_0912.heic',
        'progress': 1.0,
        'speedText': '28.4 MB/s',
        'timeLeftText': 'Completed 12m ago',
        'interface': 'Direct Wi-Fi',
      },
      {
        'fileName': 'notes_sync_conflict.txt',
        'progress': 1.0,
        'speedText': 'Recovered',
        'timeLeftText': 'Restored from trash 1h ago',
        'interface': 'Local Trash',
      },
    ];

    if (activities.isEmpty) {
      return const EmptyState(
        icon: Icons.history_outlined,
        title: 'No recent activity',
        description: 'Transfers and sync history will appear here.',
      );
    }

    return Scaffold(
      backgroundColor: TandemTokens.color_ground,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: TandemTokens.color_surface,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(TandemTokens.space_3),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final item = activities[index];
          return Container(
            margin: const EdgeInsets.only(bottom: TandemTokens.space_2),
            decoration: BoxDecoration(
              color: TandemTokens.color_surface,
              borderRadius: BorderRadius.circular(TandemTokens.radius_panel),
              border: Border.all(color: TandemTokens.color_border, width: 0.5),
            ),
            child: TransferRow(
              fileName: item['fileName'] as String,
              progress: item['progress'] as double,
              speedText: item['speedText'] as String,
              timeLeftText: item['timeLeftText'] as String,
              interface: item['interface'] as String,
            ),
          );
        },
      ),
    );
  }
}
