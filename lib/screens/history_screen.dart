import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../services/archive_trash_service.dart';
import '../services/first_launch_service.dart';
import '../services/history_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _history = HistoryService();
  final _firstLaunch = FirstLaunchService();
  final _archive = ArchiveTrashService();
  Future<List<CleanEvent>>? _events;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _events = _history.readAll();
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cleaning history?'),
        content: const Text(
          "This deletes the on-disk record of past cleans. It does NOT "
          "restore anything previously cleaned — those items remain in "
          "Trash until you empty it.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await _history.clear();
    _refresh();
  }

  void _openTrash() {
    // Finder restore-from-Trash is the canonical undo on macOS — opening
    // ~/.Trash hands the user the recovery affordance Apple already
    // built. Anything else risks the file being gone if Trash was
    // emptied between clean and restore.
    final home = Platform.environment['HOME'] ?? '';
    Process.run('open', ['$home/.Trash']);
  }

  Future<void> _restoreEvent(CleanEvent event) async {
    final restoreId = event.restoreId;
    if (restoreId == null) {
      // In-place empties (cache clean) have no recoverable archive —
      // the user has to drag whatever Trash already had back manually.
      _openTrash();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Restoring from archive…'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final result = await _archive.restore(restoreId);
      if (!mounted) return;
      if (result.allSucceeded) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${result.restored.length} '
              '${result.restored.length == 1 ? "item" : "items"}',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${result.restored.length} restored, '
              '${result.failures.length} failed — see ${result.failures.first}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  Future<void> _replayOnboarding() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replay first-launch tutorial?'),
        content: const Text(
          "This clears the markers that remember you've seen the splash, "
          "the intro tour and the live walkthrough. The next time you "
          "launch iMaculate, all three will fire from the start as if "
          "the app was freshly installed.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset markers')),
        ],
      ),
    );
    if (ok != true) return;
    await _firstLaunch.reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tutorial reset. Quit and relaunch iMaculate to see it.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          _Header(
            onClear: _clearAll,
            onOpenTrash: _openTrash,
            onReplayTutorial: _replayOnboarding,
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Expanded(
            child: FutureBuilder<List<CleanEvent>>(
              future: _events,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final events = snap.data!;
                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.clock,
                            size: 36, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text(
                          'No cleans yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cleans you run will show up here.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AuroraTokens.sp2),
                  itemBuilder: (context, i) => _EventTile(
                    event: events[i],
                    onOpenTrash: _openTrash,
                    onRestore: () => _restoreEvent(events[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onOpenTrash;
  final VoidCallback onReplayTutorial;
  const _Header({
    required this.onClear,
    required this.onOpenTrash,
    required this.onReplayTutorial,
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
                'CLEANING HISTORY',
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
                'Every clean, persisted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Files moved to Trash can be restored from Finder until '
                'the Trash is emptied.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AuroraTokens.sp4),
        OutlinedButton.icon(
          onPressed: onOpenTrash,
          icon: const Icon(CupertinoIcons.trash, size: 14),
          label: const Text('Open Trash'),
        ),
        const SizedBox(width: AuroraTokens.sp2),
        TextButton(
          onPressed: onClear,
          child: const Text('Clear log'),
        ),
        const SizedBox(width: AuroraTokens.sp2),
        TextButton.icon(
          onPressed: onReplayTutorial,
          icon: const Icon(CupertinoIcons.play_circle, size: 14),
          label: const Text('Replay tutorial'),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final CleanEvent event;
  final VoidCallback onOpenTrash;
  final VoidCallback onRestore;
  const _EventTile({
    required this.event,
    required this.onOpenTrash,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dt = event.timestamp.toLocal();
    final stamp =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp4,
        AuroraTokens.sp3,
        AuroraTokens.sp4,
        AuroraTokens.sp3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.mode.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'SF Mono',
                          fontFamilyFallback: const [
                            'Menlo',
                            'Consolas',
                            'monospace'
                          ],
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AuroraTokens.sp3),
                    Text(
                      stamp,
                      style: TextStyle(
                        fontFamily: 'SF Mono',
                        fontFamilyFallback: const [
                          'Menlo',
                          'Consolas',
                          'monospace'
                        ],
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatBytes(event.totalBytes),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              if (event.restoreId != null)
                FilledButton.tonalIcon(
                  onPressed: onRestore,
                  icon: const Icon(
                      CupertinoIcons.arrow_uturn_left, size: 14),
                  label: const Text('Restore'),
                )
              else
                TextButton.icon(
                  onPressed: onOpenTrash,
                  icon: const Icon(
                      CupertinoIcons.arrow_uturn_left, size: 14),
                  label: const Text('Open Trash'),
                ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp2),
          Wrap(
            spacing: AuroraTokens.sp3,
            runSpacing: 4,
            children: [
              for (final e in event.entries.take(8))
                Text(
                  '${e.name}  ${formatBytes(e.sizeBytes)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (event.entries.length > 8)
                Text(
                  '+${event.entries.length - 8} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
