import '../components/link_line.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double val = bytes.toDouble();
  int idx = 0;
  while (val >= 1024 && idx < units.length - 1) {
    val /= 1024;
    idx++;
  }
  final decimals = idx == 0 ? 0 : 1;
  return '${val.toStringAsFixed(decimals)} ${units[idx]}';
}

String formatSpeed(int bytesPerSec) {
  if (bytesPerSec <= 0) return '0 B/s';
  return '${formatBytes(bytesPerSec)}/s';
}

String formatLastSeen(String raw, {String fallback = 'Paired'}) {
  final s = raw.trim();
  if (s.isEmpty || s.startsWith('0001-01-01')) return fallback;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return s;
  final local = parsed.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inSeconds.abs() < 60) return 'Just now';
  if (diff.inMinutes > 0 && diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd $hh:$min';
}

LinkLineState parseLinkState(String raw) {
  switch (raw) {
    case 'direct-local':
      return LinkLineState.directLocal;
    case 'direct-internet':
      return LinkLineState.directInternet;
    case 'relayed':
      return LinkLineState.relayed;
    case 'connecting':
      return LinkLineState.connecting;
    default:
      return LinkLineState.offline;
  }
}
