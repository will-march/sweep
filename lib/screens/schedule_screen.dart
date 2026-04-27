import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/cleaning_targets.dart';
import '../models/clean_event.dart';
import '../models/cleaning_level.dart';
import '../models/scan_schedule.dart';
import '../services/cache_remover.dart';
import '../services/cache_scanner.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../services/schedule_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class ScheduleScreen extends StatefulWidget {
  /// True when the app has admin privileges. Scheduled runs respect
  /// this — without admin we still run Light Scrub, just on user-scope
  /// caches.
  final bool privileged;
  const ScheduleScreen({super.key, required this.privileged});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _service = ScheduleService();
  final _exclusions = ExclusionService();
  final _history = HistoryService();
  ScanSchedule? _current;
  bool _running = false;
  String _runMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _service.read();
    if (!mounted) return;
    setState(() => _current = s);
  }

  Future<void> _setFrequency(ScheduleFrequency f) async {
    final next = (_current ?? ScanSchedule.off).copyWith(frequency: f);
    await _service.write(next);
    if (!mounted) return;
    setState(() => _current = next);
  }

  Future<void> _runNow() async {
    if (_running) return;
    setState(() {
      _running = true;
      _runMessage = 'Scanning…';
    });

    final scanner = CacheScanner(
      privileged: widget.privileged,
      exclusions: _exclusions,
    );
    final remover = CacheRemover(privileged: widget.privileged);

    var bytes = 0;
    final logged = <CleanEventEntry>[];
    try {
      final entries = await scanner.scan(targetsFor(CleaningLevel.lightScrub));
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
        } catch (_) {/* skip individual failure */}
      }
      if (logged.isNotEmpty) {
        await _history.append(CleanEvent(
          timestamp: DateTime.now(),
          mode: '${CleaningLevel.lightScrub.name}_scheduled',
          totalBytes: bytes,
          entries: logged,
        ));
      }
      await _service.markRanNow();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _runMessage = 'Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _runMessage = bytes > 0
              ? 'Reclaimed ${formatBytes(bytes)} just now'
              : 'Nothing to reclaim';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp6,
        AuroraTokens.sp5,
        AuroraTokens.sp6,
        AuroraTokens.sp6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SCHEDULE',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-run Light Scrub',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'iMaculate runs the safest cleaning mode on a cadence you '
            'choose. Anything more aggressive stays manual — auto-running '
            'a deep clean is exactly how cleaners eat user data.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AuroraTokens.sp5),
          Wrap(
            spacing: AuroraTokens.sp2,
            children: [
              for (final f in ScheduleFrequency.values)
                _ChoiceChip(
                  label: f.title,
                  selected: s?.frequency == f,
                  onTap: () => _setFrequency(f),
                ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp5),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
            ),
            padding: const EdgeInsets.all(AuroraTokens.sp4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(CupertinoIcons.clock,
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: AuroraTokens.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s == null
                            ? 'Loading…'
                            : s.frequency == ScheduleFrequency.off
                                ? 'No schedule set'
                                : 'Running ${s.frequency.title.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s?.lastRunAt == null
                            ? 'Never run from this screen'
                            : 'Last run ${_humanWhen(s!.lastRunAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (_runMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _runMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runNow,
                  icon: _running
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFFFFF)),
                        )
                      : const Icon(CupertinoIcons.play_fill, size: 12),
                  label: Text(_running ? 'Running…' : 'Run now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuroraTokens.sp5),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
            ),
            padding: const EdgeInsets.all(AuroraTokens.sp4),
            child: Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle,
                    size: 16, color: scheme.tertiary),
                const SizedBox(width: AuroraTokens.sp2),
                Expanded(
                  child: Text(
                    'Scheduled runs only fire while iMaculate is open. '
                    'Background scheduling needs a launchd helper '
                    '(SMAppService) — that\'s on the roadmap.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _humanWhen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    final d = t.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AuroraTokens.dShort2,
          padding: const EdgeInsets.symmetric(
              horizontal: AuroraTokens.sp4, vertical: AuroraTokens.sp2),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : scheme.surfaceContainerLow,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AuroraTokens.shapeFull),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
