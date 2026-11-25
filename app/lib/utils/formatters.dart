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
