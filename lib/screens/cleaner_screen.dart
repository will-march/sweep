import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/cleaning_targets.dart';
import '../models/cache_entry.dart';
import '../models/cache_target.dart';
import '../models/clean_event.dart';
import '../models/cleaning_level.dart';
import '../services/cache_remover.dart';
import '../services/cache_scanner.dart';
import '../services/disk_stats_service.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../services/walkthrough_controller.dart';
import '../theme/level_palette.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';
import '../widgets/app_stats_row.dart';
import '../widgets/cache_tile.dart';
import '../widgets/hero_size_card.dart';

class CleanerScreen extends StatefulWidget {
  final CleaningLevel level;
  final bool privileged;
  const CleanerScreen({
    super.key,
    required this.level,
    required this.privileged,
  });

  @override
  State<CleanerScreen> createState() => _CleanerScreenState();
}

class _CleanerScreenState extends State<CleanerScreen> {
  List<CacheEntry> _entries = const [];
  bool _loading = false;
  double _scanProgress = 0;
  DiskStats? _disk;
  int _scanToken = 0;

  final ExclusionService _exclusions = ExclusionService();
  final HistoryService _history = HistoryService();

  late CacheScanner _scanner = CacheScanner(
    privileged: widget.privileged,
    exclusions: _exclusions,
  );
  late CacheRemover _remover =
      CacheRemover(privileged: widget.privileged);
  final DiskStatsService _diskStats = DiskStatsService();

  @override
  void initState() {
    super.initState();
    _loadDisk();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant CleanerScreen old) {
    super.didUpdateWidget(old);
    if (old.privileged != widget.privileged) {
      _scanner = CacheScanner(
        privileged: widget.privileged,
        exclusions: _exclusions,
      );
      _remover = CacheRemover(privileged: widget.privileged);
    }
    if (old.level != widget.level || old.privileged != widget.privileged) {
      _refresh();
    }
  }

  Future<void> _loadDisk() async {
    final d = await _diskStats.read();
    if (!mounted) return;
    setState(() => _disk = d);
  }

  Future<void> _refresh() async {
    final token = ++_scanToken;
    setState(() {
      _loading = true;
      _entries = const [];
      _scanProgress = 0;
    });

    final targets = targetsFor(widget.level);
    final accumulator = <CacheEntry>[];

    for (var i = 0; i < targets.length; i++) {
      final partial = await _scanner.scan([targets[i]]);
      if (!mounted || token != _scanToken) return;
      accumulator.addAll(partial);
      setState(() {
        _entries = List.unmodifiable(accumulator);
        _scanProgress = (i + 1) / targets.length;
      });
    }

    if (!mounted || token != _scanToken) return;
    setState(() => _loading = false);
  }

  int get _total =>
      _entries.fold<int>(0, (acc, e) => acc + e.sizeBytes);

  Future<void> _confirmAndRemove(CacheEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty cache contents?'),
        content: Text(
          '${entry.target.name}\n\n'
          '${entry.directory.path}\n\n'
          'Risk: ${entry.target.risk.label}.\n'
          'The directory is kept; only its contents are removed. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    String? error;
    final reclaimed = entry.sizeBytes;
    try {
      await _remover.empty(entry.directory, entry.target.risk);
    } catch (e) {
      error = e.toString();
    }
    if (error == null && reclaimed > 0) {
      // CacheRemover empties contents in place rather than moving to
      // Trash, so disposition is permanent. Recording this in history
      // gives the user a paper-trail even if there's nothing to undo.
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: widget.level.name,
        totalBytes: reclaimed,
        entries: [
          CleanEventEntry(
            path: entry.directory.path,
            name: entry.target.name,
            sizeBytes: reclaimed,
            disposition: 'permanently_deleted',
          ),
        ],
      ));
    }
    if (!mounted) return;
    _snack(
      error == null ? 'Emptied ${entry.target.name}' : 'Failed: $error',
      isError: error != null,
    );
    await _refresh();
  }

  Future<void> _cleanAll() async {
    if (_entries.isEmpty) return;
    final brightness = Theme.of(context).brightness;
    final accent = levelPalette(widget.level).accent(brightness);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clean ${widget.level.title}?'),
        content: Text(
          'Empty contents of ${_entries.length} '
          '${_entries.length == 1 ? "location" : "locations"}. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final failures = <String>[];
    final logged = <CleanEventEntry>[];
    for (final entry in List<CacheEntry>.from(_entries)) {
      final reclaimed = entry.sizeBytes;
      try {
        await _remover.empty(entry.directory, entry.target.risk);
        if (reclaimed > 0) {
          logged.add(CleanEventEntry(
            path: entry.directory.path,
            name: entry.target.name,
            sizeBytes: reclaimed,
            disposition: 'permanently_deleted',
          ));
        }
      } catch (e) {
        failures.add('${entry.target.name}: $e');
      }
    }
    if (logged.isNotEmpty) {
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: widget.level.name,
        totalBytes: logged.fold<int>(0, (a, e) => a + e.sizeBytes),
        entries: logged,
      ));
    }
    if (!mounted) return;
    _snack(
      failures.isEmpty
          ? 'Cleaned ${_entries.length} locations'
          : '${failures.length} failed',
      isError: failures.isNotEmpty,
    );
    await _refresh();
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.errorContainer
            : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final walk = Walkthrough.read(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AuroraTokens.sp6,
            AuroraTokens.sp5,
            AuroraTokens.sp6,
            AuroraTokens.sp4,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.level.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AuroraTokens.sp3),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(CupertinoIcons.refresh, size: 14),
                  label: const Text('Rescan'),
                ),
                const SizedBox(width: AuroraTokens.sp2),
                FilledButton.icon(
                  key: walk.cleanAllKey,
                  onPressed:
                      (_loading || _entries.isEmpty) ? null : () {
                    walk.notifyTargetUsed(WalkthroughStep.cleanAll);
                    _cleanAll();
                  },
                  icon: const Icon(CupertinoIcons.sparkles, size: 14),
                  label: const Text('Clean all'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AuroraTokens.sp6, 0, AuroraTokens.sp6, AuroraTokens.sp4,
          ),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: walk.heroKey,
              child: HeroSizeCard(
                level: widget.level,
                totalBytes: _total,
                itemCount: _entries.length,
                isLoading: _loading,
                scanProgress: _loading ? _scanProgress : 1.0,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AuroraTokens.sp6, 0, AuroraTokens.sp6, AuroraTokens.sp4,
          ),
          sliver: SliverToBoxAdapter(
            child: AppStatsRow(
              items: [
                StatItem(
                  label: 'Total disk',
                  value: _disk == null ? '—' : formatBytes(_disk!.totalBytes),
                ),
                StatItem(
                  label: 'Used',
                  value: _disk == null ? '—' : formatBytes(_disk!.usedBytes),
                ),
                StatItem(
                  label: 'Reclaimable · ${widget.level.title}',
                  value: _loading ? '…' : formatBytes(_total),
                  valueColor: scheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_loading && _entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(level: widget.level),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AuroraTokens.sp6,
              AuroraTokens.sp2,
              AuroraTokens.sp6,
              AuroraTokens.sp7,
            ),
            sliver: SliverList.separated(
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = _entries[i];
                final tile = CacheTile(
                  entry: entry,
                  onDelete: () => _confirmAndRemove(entry),
                );
                // Tag the first row so the walkthrough's "each row is a
                // finding" step can spotlight it.
                return i == 0
                    ? KeyedSubtree(key: walk.cacheRowKey, child: tile)
                    : tile;
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final CleaningLevel level;
  const _EmptyState({required this.level});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = levelPalette(level).accent(Theme.of(context).brightness);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.checkmark_alt,
              color: accent,
              size: 30,
            ),
          ),
          const SizedBox(height: AuroraTokens.sp3),
          Text(
            'All clean',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing to remove for ${level.title}.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
