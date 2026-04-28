import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../models/duplicate_group.dart';
import '../services/archive_trash_service.dart';
import '../services/duplicate_finder_service.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final _service =
      DuplicateFinderService(exclusions: ExclusionService());
  final _archive = ArchiveTrashService();
  final _history = HistoryService();

  /// Per-group: which paths the user has marked for deletion. We keep
  /// the rule that at least one path per group must remain.
  final _selected = <String>{};

  late String _root;
  int _minSizeMB = 1;
  bool _loading = false;
  String _scanningPath = '';
  List<DuplicateGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? '';
    _root = '$home/Documents';
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _selected.clear();
      _groups = const [];
      _scanningPath = '';
    });
    final result = await _service.scan(
      rootPath: _root,
      minSizeBytes: _minSizeMB * 1024 * 1024,
      onProgress: (p) {
        if (mounted) setState(() => _scanningPath = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _groups = result;
      _loading = false;
      _scanningPath = '';
    });
  }

  bool _allowToggle(DuplicateGroup g, String path, bool wantSelect) {
    if (!wantSelect) return true;
    // Always require at least one survivor per group.
    final selectedInGroup =
        g.paths.where(_selected.contains).length;
    return selectedInGroup < g.paths.length - 1;
  }

  Future<void> _trashSelected() async {
    if (_selected.isEmpty) return;
    final picked = _selected.toList();
    final total = _groups.fold<int>(0, (acc, g) {
      final n = g.paths.where(_selected.contains).length;
      return acc + g.sizeBytes * n;
    });
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Trash ${picked.length} ${picked.length == 1 ? "duplicate" : "duplicates"}?'),
        content: Text(
          "Selected duplicates are archived into Trash so you can restore "
          "from History.\n\nReclaiming ${formatBytes(total)}",
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
        label: '${picked.length} duplicate files',
        kind: 'duplicates',
        sourcePaths: picked,
      );
      final logged = entry.items
          .map((i) => CleanEventEntry(
                path: i.originalPath,
                name: 'duplicate · ${_basename(i.originalPath)}',
                sizeBytes: i.sizeBytes,
                disposition: 'archived_in_trash',
              ))
          .toList();
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'duplicates',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reclaimable = _groups.fold<int>(0, (a, g) => a + g.reclaimableBytes);
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
                      'DUPLICATES',
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
                      'Same file, in many places',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Files that match by size + SHA-256. At least one '
                      'copy is always kept.',
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
                      : 'Trash ${_selected.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          _Filters(
            root: _root,
            minSizeMB: _minSizeMB,
            onChanged: (root, mb) {
              setState(() {
                _root = root;
                _minSizeMB = mb;
              });
              _scan();
            },
          ),
          const SizedBox(height: AuroraTokens.sp3),
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
              '${_groups.length} duplicate ${_groups.length == 1 ? "group" : "groups"} · '
              '${formatBytes(reclaimable)} reclaimable',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AuroraTokens.sp3),
          Expanded(
            child: _groups.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark_alt_circle,
                            size: 36, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text(
                          'No duplicates found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuroraTokens.sp2),
                    itemBuilder: (context, i) => _GroupTile(
                      group: _groups[i],
                      selected: _selected,
                      canSelect: (path, want) =>
                          _allowToggle(_groups[i], path, want),
                      onChanged: () => setState(() {}),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String root;
  final int minSizeMB;
  final void Function(String root, int minSizeMB) onChanged;
  const _Filters({
    required this.root,
    required this.minSizeMB,
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
      padding: const EdgeInsets.all(AuroraTokens.sp3),
      child: Row(
        children: [
          Icon(CupertinoIcons.slider_horizontal_3,
              size: 14, color: scheme.primary),
          const SizedBox(width: AuroraTokens.sp2),
          Text('Larger than',
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(width: AuroraTokens.sp2),
          DropdownButton<int>(
            value: minSizeMB,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 MB')),
              DropdownMenuItem(value: 10, child: Text('10 MB')),
              DropdownMenuItem(value: 50, child: Text('50 MB')),
              DropdownMenuItem(value: 100, child: Text('100 MB')),
            ],
            onChanged: (v) => v != null ? onChanged(root, v) : null,
          ),
          const SizedBox(width: AuroraTokens.sp4),
          Expanded(
            child: Text(
              'Searching $root',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontFamily: 'SF Mono',
                fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final DuplicateGroup group;
  final Set<String> selected;
  final bool Function(String path, bool wantSelect) canSelect;
  final VoidCallback onChanged;
  const _GroupTile({
    required this.group,
    required this.selected,
    required this.canSelect,
    required this.onChanged,
  });

  String _basename(String path) {
    final clean =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = clean.lastIndexOf('/');
    return i < 0 ? clean : clean.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
      ),
      padding: const EdgeInsets.all(AuroraTokens.sp3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.paths.length} copies · '
                  '${_basename(group.paths.first)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${formatBytes(group.sizeBytes)} each · '
                'reclaim ${formatBytes(group.reclaimableBytes)}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp2),
          for (final path in group.paths)
            _PathRow(
              path: path,
              checked: selected.contains(path),
              onChanged: () {
                final wantSelect = !selected.contains(path);
                if (!canSelect(path, wantSelect)) return;
                if (wantSelect) {
                  selected.add(path);
                } else {
                  selected.remove(path);
                }
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  final String path;
  final bool checked;
  final VoidCallback onChanged;
  const _PathRow({
    required this.path,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(value: checked, onChanged: (_) => onChanged()),
          const SizedBox(width: AuroraTokens.sp2),
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
