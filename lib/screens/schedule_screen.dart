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
import '../services/launchd_agent_service.dart';
import '../services/schedule_service.dart';
import '../services/threat_definitions_service.dart';
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
  final _defs = ThreatDefinitionsService();
  final _agent = LaunchdAgentService();
  ScanSchedule? _current;
  bool _running = false;
  String _runMessage = '';
  bool _agentBusy = false;

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
    // If the agent's already installed and the frequency changed,
    // re-bootstrap so launchd picks up the new calendar interval.
    if (next.backgroundAgentInstalled) {
      await _agent.install(next);
    }
  }

  Future<void> _setLightScrub(bool on) =>
      _patch((s) => s.copyWith(runLightScrub: on));

  Future<void> _setThreatScan(bool on) =>
      _patch((s) => s.copyWith(runThreatScan: on));

  Future<void> _setUpdateDefs(bool on) =>
      _patch((s) => s.copyWith(updateDefinitions: on));

  Future<void> _patch(
      ScanSchedule Function(ScanSchedule) f) async {
    final next = f(_current ?? ScanSchedule.off);
    await _service.write(next);
    if (!mounted) return;
    setState(() => _current = next);
    if (next.backgroundAgentInstalled) {
      // No-op for these toggles since the plist itself only carries
      // frequency, but keeps things explicit.
    }
  }

  Future<void> _toggleAgent(bool desired) async {
    final s = _current;
    if (s == null) return;
    setState(() => _agentBusy = true);
    try {
      final result = desired
          ? await _agent.install(s)
          : await _agent.uninstall();
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _runMessage =
            'launchd error: ${result.message ?? "unknown"}');
      } else {
        final next = s.copyWith(backgroundAgentInstalled: desired);
        await _service.write(next);
        if (!mounted) return;
        setState(() {
          _current = next;
          _runMessage = desired
              ? 'Background scheduler enabled — runs at 03:30 local time'
              : 'Background scheduler disabled';
        });
      }
    } finally {
      if (mounted) setState(() => _agentBusy = false);
    }
  }

  Future<void> _runNow() async {
    if (_running) return;
    final s = _current ?? ScanSchedule.off;
    setState(() {
      _running = true;
      _runMessage = 'Running scheduled job…';
    });
    var bytes = 0;
    try {
      if (s.runLightScrub) {
        bytes += await _runLightScrub();
      }
      if (s.updateDefinitions) {
        await _defs.update();
      }
      if (s.runThreatScan) {
        // The scan itself is invoked via the headless path so the
        // History append is identical to background runs. Inline run
        // here is a no-op placeholder — the user can fire the full
        // scan from the Threat Scan screen.
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
              : 'Run complete';
        });
      }
    }
  }

  Future<int> _runLightScrub() async {
    final scanner = CacheScanner(
      privileged: widget.privileged,
      exclusions: _exclusions,
    );
    final remover = CacheRemover(privileged: widget.privileged);

    var bytes = 0;
    final logged = <CleanEventEntry>[];
    final entries =
        await scanner.scan(targetsFor(CleaningLevel.lightScrub));
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
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _current;
    return SingleChildScrollView(
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
            'Cleans + threat scans on a cadence',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a frequency, choose which jobs run, and (optionally) '
            'install a launchd agent so the schedule fires even when '
            "Sweep isn't open. The agent runs in your user session "
            'at 03:30 local time on the cadence you choose.',
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
          const SizedBox(height: AuroraTokens.sp4),
          _TaskCard(
            title: 'Tasks to run',
            children: [
              _TaskToggle(
                title: 'Light Scrub',
                subtitle:
                    'Empty user caches and logs. Always safe to auto-run.',
                value: s?.runLightScrub ?? true,
                onChanged: _setLightScrub,
              ),
              _TaskToggle(
                title: 'Threat scan',
                subtitle:
                    'Hash-match /Applications + ~/Downloads against the '
                    'open-source threat feed.',
                value: s?.runThreatScan ?? false,
                onChanged: _setThreatScan,
              ),
              _TaskToggle(
                title: 'Update threat definitions before scanning',
                subtitle:
                    'Pulls the latest signatures from abuse.ch '
                    '(MalwareBazaar). ~MB download.',
                value: s?.updateDefinitions ?? true,
                onChanged: _setUpdateDefs,
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          _RunNowCard(
            schedule: s,
            running: _running,
            message: _runMessage,
            onRun: _runNow,
          ),
          const SizedBox(height: AuroraTokens.sp4),
          _BackgroundAgentCard(
            installed: s?.backgroundAgentInstalled ?? false,
            busy: _agentBusy,
            disabled: s == null ||
                s.frequency == ScheduleFrequency.off,
            onChanged: _toggleAgent,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _TaskCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.all(AuroraTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AuroraTokens.sp3),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: AuroraTokens.sp4,
                thickness: 1,
                color: scheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _TaskToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TaskToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AuroraTokens.sp3),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _RunNowCard extends StatelessWidget {
  final ScanSchedule? schedule;
  final bool running;
  final String message;
  final VoidCallback onRun;
  const _RunNowCard({
    required this.schedule,
    required this.running,
    required this.message,
    required this.onRun,
  });

  static String _humanWhen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    final d = t.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = schedule;
    return Container(
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
            child:
                Icon(CupertinoIcons.clock, size: 18, color: scheme.primary),
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
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message,
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
            onPressed: running ? null : onRun,
            icon: running
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFFFFFFF)),
                  )
                : const Icon(CupertinoIcons.play_fill, size: 12),
            label: Text(running ? 'Running…' : 'Run now'),
          ),
        ],
      ),
    );
  }
}

class _BackgroundAgentCard extends StatelessWidget {
  final bool installed;
  final bool busy;
  final bool disabled;
  final ValueChanged<bool> onChanged;
  const _BackgroundAgentCard({
    required this.installed,
    required this.busy,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.all(AuroraTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.gear_solid,
                    size: 18, color: scheme.primary),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background scheduler (launchd)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      installed
                          ? 'Installed at ~/Library/LaunchAgents/'
                              'dev.willmarch.sweep.scheduler.plist'
                          : 'Off — schedule only fires when the GUI is open',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: installed,
                  onChanged: disabled ? null : onChanged,
                ),
            ],
          ),
          if (disabled) ...[
            const SizedBox(height: AuroraTokens.sp2),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AuroraTokens.shapeSm),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle,
                      size: 14, color: scheme.tertiary),
                  const SizedBox(width: AuroraTokens.sp2),
                  Expanded(
                    child: Text(
                      'Pick a frequency above first — installing a '
                      'launchd agent with no schedule does nothing.',
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
        ],
      ),
    );
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
