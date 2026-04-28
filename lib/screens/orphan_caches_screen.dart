import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../models/orphan_cache.dart';
import '../services/archive_trash_service.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../services/orphan_caches_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class OrphanCachesScreen extends StatefulWidget {
  const OrphanCachesScreen({super.key});

  @override
  State<OrphanCachesScreen> createState() => _OrphanCachesScreenState();
}

class _OrphanCachesScreenState extends State<OrphanCachesScreen> {
  final _service = OrphanCachesService(exclusions: ExclusionService());
  final _archive = ArchiveTrashService();
  final _history = HistoryService();
  final _selected = <String>{};
  bool _loading = false;
  String _scanningPath = '';
  List<OrphanCache> _items = const [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _selected.clear();
      _items = const [];
      _scanningPath = '';
    });
    final result = await _service.scan(onProgress: (p) {
      if (mounted) setState(() => _scanningPath = p);
    });
    if (!mounted) return;
    setState(() {
      _items = result;
      _loading = false;
      _scanningPath = '';
    });
  }

  Future<void> _trashSelected() async {
    final picked = _items.where((c) => _selected.contains(c.path)).toList();
    if (picked.isEmpty) return;
    final total = picked.fold<int>(0, (a, c) => a + c.sizeBytes);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Trash ${picked.length} '
            '${picked.length == 1 ? "cache" : "caches"}?'),
        content: Text(
          "Each cache is archived into Trash so you can restore from History. "
          "Re-running the project's package manager will rebuild it.\n\n"
          "Total: ${formatBytes(total)}",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Move to Trash')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final entry = await _archive.archiveAndTrash(
        label: picked.length == 1
            ? '${picked.first.kind} · ${_basename(picked.first.projectPath)}'
            : '${picked.length} project caches',
        kind: 'orphan-caches',
        sourcePaths: picked.map((c) => c.path).toList(),
      );
      final logged = entry.items
          .map((i) => CleanEventEntry(
                path: i.originalPath,
                name:
                    '${_basename(_parent(i.originalPath))} · ${_basename(i.originalPath)}',
                sizeBytes: i.sizeBytes,
                disposition: 'archived_in_trash',
              ))
          .toList();
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'orphan_caches',
        totalBytes: entry.totalBytes,
        entries: logged,
        restoreId: entry.id,
      ));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Reclaimed ${formatBytes(entry.totalBytes)} — restorable from History')));
      _scan();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Trash failed: $e')));
    }
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }

  String _parent(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i <= 0 ? '' : clean.substring(0, i);
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROJECT CACHES',
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
                      'node_modules and friends',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Per-project build caches Sweep finds in your usual '
                      'project roots. Each row is recoverable from Trash.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              OutlinedButton.icon(
                onPressed: _loading ? null : _scan,
                icon: const Icon(CupertinoIcons.refresh, size: 14),
                label: const Text('Rescan'),
              ),
              const SizedBox(width: AuroraTokens.sp2),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _trashSelected,
                icon: const Icon(CupertinoIcons.trash, size: 14),
                label: Text(
                  _selected.isEmpty
                      ? 'Trash selected'
                      : 'Trash ${_selected.length} selected',
                ),
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          if (_loading)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AuroraTokens.sp2),
                Expanded(
                  child: Text(
                    'Scanning… $_scanningPath',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: const [
                        'Menlo',
                        'Consolas',
                        'monospace'
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              '${_items.length} ${_items.length == 1 ? "cache" : "caches"}'
              ' · ${formatBytes(_items.fold<int>(0, (a, c) => a + c.sizeBytes))}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AuroraTokens.sp3),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.cube_box,
                            size: 36, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text(
                          'No project caches found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sweep looks in ~/Documents, ~/Developer, ~/code, '
                          '~/Projects, ~/src, ~/repos, ~/work, ~/dev, ~/Desktop.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuroraTokens.sp1),
                    itemBuilder: (context, i) {
                      final c = _items[i];
                      final selected = _selected.contains(c.path);
                      return _CacheRow(
                        cache: c,
                        selected: selected,
                        onToggle: () => setState(() {
                          if (selected) {
                            _selected.remove(c.path);
                          } else {
                            _selected.add(c.path);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CacheRow extends StatelessWidget {
  final OrphanCache cache;
  final bool selected;
  final VoidCallback onToggle;
  const _CacheRow({
    required this.cache,
    required this.selected,
    required this.onToggle,
  });

  static String _humanWhen(DateTime? t) {
    if (t == null) return 'unknown';
    final diff = DateTime.now().difference(t);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 30) return '${diff.inDays} d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} mo ago';
    return '${(diff.inDays / 365).round()} y ago';
  }

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = cache.projectLastTouched != null &&
        DateTime.now().difference(cache.projectLastTouched!).inDays > 90;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: AuroraTokens.dShort2,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.surfaceContainerLow,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
          ),
          padding: const EdgeInsets.fromLTRB(
              AuroraTokens.sp3, AuroraTokens.sp3, AuroraTokens.sp3, AuroraTokens.sp3),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: AuroraTokens.sp2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cache.kind,
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: const [
                      'Menlo',
                      'Consolas',
                      'monospace'
                    ],
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _basename(cache.projectPath),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cache.projectPath,
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
                  ],
                ),
              ),
              const SizedBox(width: AuroraTokens.sp3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBytes(cache.sizeBytes),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'project ${_humanWhen(cache.projectLastTouched)}',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          stale ? scheme.tertiary : scheme.onSurfaceVariant,
                      fontWeight: stale ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
