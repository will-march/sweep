import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/big_old_file.dart';
import '../models/clean_event.dart';
import '../services/archive_trash_service.dart';
import '../services/big_old_files_service.dart';
import '../services/exclusion_service.dart';
import '../services/history_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class BigOldFilesScreen extends StatefulWidget {
  const BigOldFilesScreen({super.key});

  @override
  State<BigOldFilesScreen> createState() => _BigOldFilesScreenState();
}

class _BigOldFilesScreenState extends State<BigOldFilesScreen> {
  final _service = BigOldFilesService(exclusions: ExclusionService());
  final _archive = ArchiveTrashService();
  final _history = HistoryService();
  final _selected = <String>{};

  late String _root;
  int _minSizeMB = 100;
  int _minAgeDays = 180;
  bool _loading = false;
  String _scanningPath = '';
  List<BigOldFile> _items = const [];

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? '';
    _root = home;
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _selected.clear();
      _items = const [];
      _scanningPath = '';
    });
    final result = await _service.scan(
      rootPath: _root,
      minSizeBytes: _minSizeMB * 1024 * 1024,
      minAge: Duration(days: _minAgeDays),
      onProgress: (p) {
        if (mounted) setState(() => _scanningPath = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _items = result;
      _loading = false;
      _scanningPath = '';
    });
  }

  Future<void> _trashSelected() async {
    final picked = _items.where((f) => _selected.contains(f.path)).toList();
    if (picked.isEmpty) return;
    final total = picked.fold<int>(0, (a, f) => a + f.sizeBytes);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Trash ${picked.length} ${picked.length == 1 ? "file" : "files"}?'),
        content: Text(
          "Sweep archives the selection into Trash so you can restore from "
          "History.\n\nTotal: ${formatBytes(total)}",
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
            ? _basename(picked.first.path)
            : '${picked.length} big & old files',
        kind: 'big-old-files',
        sourcePaths: picked.map((f) => f.path).toList(),
      );
      final logged = entry.items
          .map((i) => CleanEventEntry(
                path: i.originalPath,
                name: _basename(i.originalPath),
                sizeBytes: i.sizeBytes,
                disposition: 'archived_in_trash',
              ))
          .toList();
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'big_old_files',
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
                      'BIG & OLD FILES',
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
                      'Things you forgot you had',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Files above the size threshold that you haven\'t '
                      'opened in a while.',
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
          _Filters(
            root: _root,
            minSizeMB: _minSizeMB,
            minAgeDays: _minAgeDays,
            onChanged: (root, mb, days) {
              setState(() {
                _root = root;
                _minSizeMB = mb;
                _minAgeDays = days;
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
              '${_items.length} files · '
              '${formatBytes(_items.fold<int>(0, (a, f) => a + f.sizeBytes))}',
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
                        Icon(CupertinoIcons.checkmark_alt_circle,
                            size: 36, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text(
                          'Nothing big and old',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AuroraTokens.sp1),
                    itemBuilder: (context, i) {
                      final f = _items[i];
                      final selected = _selected.contains(f.path);
                      return _FileRow(
                        file: f,
                        selected: selected,
                        onToggle: () => setState(() {
                          if (selected) {
                            _selected.remove(f.path);
                          } else {
                            _selected.add(f.path);
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

class _Filters extends StatelessWidget {
  final String root;
  final int minSizeMB;
  final int minAgeDays;
  final void Function(String root, int minSizeMB, int minAgeDays) onChanged;
  const _Filters({
    required this.root,
    required this.minSizeMB,
    required this.minAgeDays,
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
              DropdownMenuItem(value: 50, child: Text('50 MB')),
              DropdownMenuItem(value: 100, child: Text('100 MB')),
              DropdownMenuItem(value: 250, child: Text('250 MB')),
              DropdownMenuItem(value: 500, child: Text('500 MB')),
              DropdownMenuItem(value: 1024, child: Text('1 GB')),
            ],
            onChanged: (v) => v != null ? onChanged(root, v, minAgeDays) : null,
          ),
          const SizedBox(width: AuroraTokens.sp4),
          Text('Untouched for',
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(width: AuroraTokens.sp2),
          DropdownButton<int>(
            value: minAgeDays,
            isDense: true,
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 90, child: Text('3 months')),
              DropdownMenuItem(value: 180, child: Text('6 months')),
              DropdownMenuItem(value: 365, child: Text('1 year')),
              DropdownMenuItem(value: 730, child: Text('2 years')),
            ],
            onChanged: (v) => v != null ? onChanged(root, minSizeMB, v) : null,
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

class _FileRow extends StatelessWidget {
  final BigOldFile file;
  final bool selected;
  final VoidCallback onToggle;
  const _FileRow({
    required this.file,
    required this.selected,
    required this.onToggle,
  });

  static String _humanWhen(DateTime t) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _basename(file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.path,
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
                    formatBytes(file.sizeBytes),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _humanWhen(file.lastUsed),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
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
