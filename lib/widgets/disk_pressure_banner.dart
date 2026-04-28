import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/cleaning_targets.dart';
import '../models/clean_event.dart';
import '../models/cleaning_level.dart';
import '../services/cache_remover.dart';
import '../services/cache_scanner.dart';
import '../services/disk_stats_service.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

/// Soft alert that appears when the boot volume is running tight on
/// space. Polls `df -k /` every five minutes and shows a one-click
/// Light Scrub trigger when the free fraction or absolute free bytes
/// drops below the threshold.
///
/// Thresholds are deliberately soft — the banner is a nudge, not a
/// blocker. The user can dismiss it; we'll re-check on the next poll.
class DiskPressureBanner extends StatefulWidget {
  final bool privileged;
  const DiskPressureBanner({super.key, required this.privileged});

  @override
  State<DiskPressureBanner> createState() => _DiskPressureBannerState();
}

class _DiskPressureBannerState extends State<DiskPressureBanner> {
  static const _minFreeFraction = 0.10; // 10 %
  static const _minFreeBytes = 10 * 1024 * 1024 * 1024; // 10 GB
  static const _pollEvery = Duration(minutes: 5);

  final _diskStats = DiskStatsService();
  final _history = HistoryService();
  Timer? _timer;
  DiskStats? _stats;
  bool _dismissed = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_pollEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await _diskStats.read();
    if (!mounted) return;
    setState(() => _stats = s);
  }

  bool get _underPressure {
    final s = _stats;
    if (s == null || s.totalBytes == 0) return false;
    final freeFraction = s.freeBytes / s.totalBytes;
    return freeFraction < _minFreeFraction || s.freeBytes < _minFreeBytes;
  }

  Future<void> _runLightScrub() async {
    if (_running) return;
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final scanner = CacheScanner(
        privileged: widget.privileged,
        exclusions: ExclusionService(),
      );
      final remover = CacheRemover(privileged: widget.privileged);
      final entries =
          await scanner.scan(targetsFor(CleaningLevel.lightScrub));
      var bytes = 0;
      final logged = <CleanEventEntry>[];
      for (final e in entries) {
        try {
          await remover.empty(e.directory, e.target.risk);
          if (e.sizeBytes > 0) {
            bytes += e.sizeBytes;
            logged.add(CleanEventEntry(
              path: e.directory.path,
              name: e.target.name,
              sizeBytes: e.sizeBytes,
              disposition: 'permanently_deleted',
            ));
          }
        } catch (_) {/* skip */}
      }
      if (logged.isNotEmpty) {
        await _history.append(CleanEvent(
          timestamp: DateTime.now(),
          mode: '${CleaningLevel.lightScrub.name}_pressure',
          totalBytes: bytes,
          entries: logged,
        ));
      }
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(bytes > 0
            ? 'Reclaimed ${formatBytes(bytes)} via Light Scrub'
            : 'Light Scrub finished — nothing to reclaim'),
      ));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    if (!_underPressure) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final s = _stats!;
    final freePct = (s.freeBytes / s.totalBytes * 100).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AuroraTokens.sp4,
        AuroraTokens.sp2,
        AuroraTokens.sp4,
        0,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.10),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp3,
        AuroraTokens.sp2,
        AuroraTokens.sp2,
        AuroraTokens.sp2,
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_circle,
              size: 16, color: scheme.tertiary),
          const SizedBox(width: AuroraTokens.sp2),
          Expanded(
            child: Text(
              'Disk is tight — ${formatBytes(s.freeBytes)} free '
              '($freePct %). Run a Light Scrub now?',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AuroraTokens.sp2),
          FilledButton.tonalIcon(
            onPressed: _running ? null : _runLightScrub,
            icon: _running
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.sparkles, size: 12),
            label: Text(_running ? 'Cleaning…' : 'Light Scrub'),
          ),
          const SizedBox(width: AuroraTokens.sp1),
          IconButton(
            tooltip: 'Dismiss until next poll',
            iconSize: 14,
            onPressed: () => setState(() => _dismissed = true),
            icon: const Icon(CupertinoIcons.xmark),
          ),
        ],
      ),
    );
  }
}
