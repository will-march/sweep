import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../models/launch_item.dart';
import '../models/nav_selection.dart';
import '../services/archive_trash_service.dart';
import '../services/history_service.dart';
import '../services/launch_items_service.dart';
import '../services/threat_definitions_service.dart';
import '../services/threat_scanner.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class SecurityScreen extends StatelessWidget {
  final SecurityView view;
  const SecurityScreen({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      SecurityView.launchItems => const _LaunchItemsTab(),
      SecurityView.threatScan => const _ThreatScanTab(),
    };
  }
}

// =========================================================================
// Launch Items
// =========================================================================

class _LaunchItemsTab extends StatefulWidget {
  const _LaunchItemsTab();

  @override
  State<_LaunchItemsTab> createState() => _LaunchItemsTabState();
}

class _LaunchItemsTabState extends State<_LaunchItemsTab> {
  final _service = LaunchItemsService();
  final _archive = ArchiveTrashService();
  final _history = HistoryService();
  Future<List<LaunchItem>>? _items;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _items = _service.scan();
    });
  }

  Future<void> _trash(LaunchItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disable launch item?'),
        content: Text(
          '${item.label}\n${item.plistPath}\n\n'
          'The plist is archived to ~/.Trash and removed from disk. '
          'Restore from History if you change your mind.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive + remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final entry = await _archive.archiveAndTrash(
        label: item.label,
        kind: 'launch_item',
        sourcePaths: [item.plistPath],
      );
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'launch_item',
        totalBytes: entry.totalBytes,
        entries: [
          CleanEventEntry(
            path: item.plistPath,
            name: item.label,
            sizeBytes: entry.totalBytes,
            disposition: 'archived_in_trash',
          ),
        ],
        restoreId: entry.id,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disabled ${item.label}')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAUNCH ITEMS',
                      style: TextStyle(
                        fontFamily: 'SF Mono',
                        fontFamilyFallback: const [
                          'Menlo',
                          'Consolas',
                          'monospace'
                        ],
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Anything that runs at login',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scans ~/Library/LaunchAgents, /Library/LaunchAgents '
                      'and /Library/LaunchDaemons. Items that look out of '
                      'place (paths in /tmp, inline shell, known adware '
                      'labels) are flagged.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(CupertinoIcons.refresh, size: 14),
                label: const Text('Rescan'),
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Expanded(
            child: FutureBuilder<List<LaunchItem>>(
              future: _items,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text('No launch items found',
                        style:
                            TextStyle(color: scheme.onSurfaceVariant)),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AuroraTokens.sp1),
                  itemBuilder: (context, i) =>
                      _LaunchItemRow(item: items[i], onTrash: _trash),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchItemRow extends StatelessWidget {
  final LaunchItem item;
  final ValueChanged<LaunchItem> onTrash;
  const _LaunchItemRow({required this.item, required this.onTrash});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final flagColor =
        item.suspicious ? scheme.error : scheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: item.suspicious
              ? scheme.error.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp4,
        AuroraTokens.sp3,
        AuroraTokens.sp4,
        AuroraTokens.sp3,
      ),
      child: Row(
        children: [
          Icon(
            item.suspicious
                ? CupertinoIcons.exclamationmark_triangle_fill
                : CupertinoIcons.bolt_fill,
            size: 16,
            color: flagColor,
          ),
          const SizedBox(width: AuroraTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      label: item.scope.label,
                      tone: item.scope.isPrivileged
                          ? scheme.error
                          : scheme.primary,
                    ),
                    if (item.runAtLoad) ...[
                      const SizedBox(width: 4),
                      _Chip(
                          label: 'RunAtLoad',
                          tone: scheme.tertiary),
                    ],
                    if (item.suspicious) ...[
                      const SizedBox(width: 4),
                      _Chip(label: 'SUSPICIOUS', tone: scheme.error),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.program ?? '(no program — likely a binary plist)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: const [
                      'Menlo',
                      'Consolas',
                      'monospace'
                    ],
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  item.plistPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: const [
                      'Menlo',
                      'Consolas',
                      'monospace'
                    ],
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuroraTokens.sp3),
          OutlinedButton.icon(
            onPressed: () => onTrash(item),
            icon: const Icon(CupertinoIcons.trash, size: 14),
            label: const Text('Disable'),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// Threat Scan
// =========================================================================

class _ThreatScanTab extends StatefulWidget {
  const _ThreatScanTab();

  @override
  State<_ThreatScanTab> createState() => _ThreatScanTabState();
}

class _ThreatScanTabState extends State<_ThreatScanTab> {
  final _defs = ThreatDefinitionsService();
  final _archive = ArchiveTrashService();
  final _history = HistoryService();

  ThreatDefinitions _definitions = ThreatDefinitions.empty;
  bool _updating = false;
  String _statusMessage = '';

  bool _scanning = false;
  ThreatScanProgress? _progress;
  StreamSubscription<ThreatScanProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadDefinitions() async {
    final d = await _defs.read();
    if (!mounted) return;
    setState(() => _definitions = d);
  }

  Future<void> _updateDefinitions() async {
    setState(() {
      _updating = true;
      _statusMessage = 'Fetching latest signatures…';
    });
    try {
      final next = await _defs.update();
      if (!mounted) return;
      setState(() {
        _definitions = next;
        _statusMessage =
            'Updated · ${next.signatures.length} signatures loaded';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _runScan() async {
    if (_scanning) return;
    if (_definitions.signatures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No threat signatures yet — tap "Update definitions" first.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _scanning = true;
      _progress = null;
    });
    final scanner = ThreatScanner(definitions: _definitions);
    final home = Platform.environment['HOME'] ?? '';
    final targets = <String>[
      '/Applications',
      if (home.isNotEmpty) '$home/Downloads',
      if (home.isNotEmpty) '$home/Library/LaunchAgents',
    ];
    _sub?.cancel();
    _sub = scanner.scan(targets).listen((p) {
      if (!mounted) return;
      setState(() {
        _progress = p;
        _scanning = !p.finished;
      });
    });
  }

  Future<void> _quarantine(ThreatHit hit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quarantine threat?'),
        content: Text(
          '${hit.signature.name.isEmpty ? "Unknown family" : hit.signature.name}\n'
          '${hit.path}\n\n'
          'Archives the file to ~/.Trash and removes the original. '
          'Restore from History if it was a false positive.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quarantine')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final entry = await _archive.archiveAndTrash(
        label: hit.signature.name.isEmpty
            ? 'threat'
            : hit.signature.name,
        kind: 'threat',
        sourcePaths: [hit.path],
      );
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'threat',
        totalBytes: entry.totalBytes,
        entries: [
          CleanEventEntry(
            path: hit.path,
            name: hit.signature.name,
            sizeBytes: hit.sizeBytes,
            disposition: 'archived_in_trash',
          ),
        ],
        restoreId: entry.id,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quarantined.')),
      );
      // Drop the hit from the in-progress list locally so the user
      // doesn't see it again until next scan.
      setState(() {
        if (_progress != null) {
          final remaining =
              _progress!.hits.where((h) => h.path != hit.path).toList();
          _progress = ThreatScanProgress(
            currentPath: _progress!.currentPath,
            filesScanned: _progress!.filesScanned,
            filesPlanned: _progress!.filesPlanned,
            hitsCount: remaining.length,
            hits: remaining,
            finished: _progress!.finished,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quarantine failed: $e')),
      );
    }
  }

  String _humanWhen(DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
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
    final updatedAt = _definitions.updatedAt;
    final hits = _progress?.hits ?? const <ThreatHit>[];
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
            'THREAT SCAN',
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
            'Hash-match against open-source threat feed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Definitions come from abuse.ch MalwareBazaar — public, '
            'open-source, updated daily. Hashes are stored locally so '
            'the scan itself runs offline.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AuroraTokens.sp4),
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
                  child: Icon(CupertinoIcons.shield_lefthalf_fill,
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: AuroraTokens.sp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _definitions.signatures.isEmpty
                            ? 'No definitions yet'
                            : '${_definitions.signatures.length} signatures loaded',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        updatedAt == null
                            ? 'Tap "Update definitions" to fetch the latest list'
                            : 'Updated ${_humanWhen(updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (_statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _statusMessage,
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
                  onPressed: _updating ? null : _updateDefinitions,
                  icon: _updating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFFFFF)),
                        )
                      : const Icon(CupertinoIcons.cloud_download_fill,
                          size: 14),
                  label: Text(
                      _updating ? 'Updating…' : 'Update definitions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuroraTokens.sp3),
          Row(
            children: [
              FilledButton.icon(
                onPressed:
                    _scanning || _definitions.signatures.isEmpty
                        ? null
                        : _runScan,
                icon: const Icon(CupertinoIcons.search, size: 14),
                label: Text(_scanning ? 'Scanning…' : 'Scan now'),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              if (_progress != null)
                Expanded(
                  child: _ScanStatus(progress: _progress!),
                ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Expanded(
            child: hits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _progress?.finished == true
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.shield,
                          size: 36,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text(
                          _progress?.finished == true
                              ? 'No threats detected'
                              : _scanning
                                  ? 'Scanning…'
                                  : 'Run a scan to check this Mac',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: hits.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuroraTokens.sp1),
                    itemBuilder: (context, i) => _ThreatHitRow(
                      hit: hits[i],
                      onQuarantine: _quarantine,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScanStatus extends StatelessWidget {
  final ThreatScanProgress progress;
  const _ScanStatus({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = progress.filesPlanned == 0
        ? 0.0
        : (progress.filesScanned / progress.filesPlanned).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.finished
                    ? '${progress.filesScanned} files scanned · '
                        '${progress.hitsCount} hit'
                        '${progress.hitsCount == 1 ? "" : "s"}'
                    : progress.currentPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'SF Mono',
                  fontFamilyFallback: const [
                    'Menlo',
                    'Consolas',
                    'monospace'
                  ],
                  fontSize: 12,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AuroraTokens.sp2),
            Text(
              progress.filesPlanned == 0
                  ? '—'
                  : '${progress.filesScanned} / ${progress.filesPlanned}',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontFamilyFallback: const [
                  'Menlo',
                  'Consolas',
                  'monospace'
                ],
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.finished ? 1.0 : pct,
            minHeight: 4,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _ThreatHitRow extends StatelessWidget {
  final ThreatHit hit;
  final ValueChanged<ThreatHit> onQuarantine;
  const _ThreatHitRow({required this.hit, required this.onQuarantine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.error.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.fromLTRB(
        AuroraTokens.sp4,
        AuroraTokens.sp3,
        AuroraTokens.sp4,
        AuroraTokens.sp3,
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_octagon_fill,
              size: 18, color: scheme.error),
          const SizedBox(width: AuroraTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.signature.name.isEmpty
                      ? 'Unknown family'
                      : hit.signature.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hit.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: const [
                      'Menlo',
                      'Consolas',
                      'monospace'
                    ],
                    fontSize: 11,
                    color: scheme.onErrorContainer
                        .withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${formatBytes(hit.sizeBytes)} · '
                  'sha256 ${hit.signature.sha256.substring(0, 12)}…  '
                  '· ${hit.signature.source}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onErrorContainer
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuroraTokens.sp3),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => onQuarantine(hit),
            icon: const Icon(CupertinoIcons.lock_shield_fill, size: 14),
            label: const Text('Quarantine'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color tone;
  const _Chip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'SF Mono',
          fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
          fontSize: 9,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}
