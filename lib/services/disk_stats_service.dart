import 'dart:io';

class DiskStats {
  final int totalBytes;
  final int usedBytes;
  const DiskStats({required this.totalBytes, required this.usedBytes});
  int get freeBytes => totalBytes - usedBytes;
}

class DiskStatsService {
  /// Read root volume stats via `df -k /`. Returns null if parsing fails.
  Future<DiskStats?> read() async {
    try {
      final r = await Process.run('df', ['-k', '/']);
      if (r.exitCode != 0) return null;
      final lines = r.stdout.toString().split('\n');
      if (lines.length < 2) return null;
      final parts = lines[1].split(RegExp(r'\s+'));
      // df output: Filesystem 1024-blocks Used Available Capacity ...
      if (parts.length < 4) return null;
      final total1k = int.tryParse(parts[1]) ?? 0;
      final used1k = int.tryParse(parts[2]) ?? 0;
      return DiskStats(
        totalBytes: total1k * 1024,
        usedBytes: used1k * 1024,
      );
    } catch (_) {
      return null;
    }
  }
}
