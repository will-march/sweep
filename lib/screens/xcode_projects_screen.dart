import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../models/xcode_project.dart';
import '../services/archive_trash_service.dart';
import '../services/history_service.dart';
import '../services/xcode_derived_data_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class XcodeProjectsScreen extends StatefulWidget {
  const XcodeProjectsScreen({super.key});

  @override
  State<XcodeProjectsScreen> createState() => _XcodeProjectsScreenState();
}

class _XcodeProjectsScreenState extends State<XcodeProjectsScreen> {
  final _service = XcodeDerivedDataService();
  final _archive = ArchiveTrashService();
  final _history = HistoryService();
  final _selected = <String>{};
  Future<List<XcodeProject>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _selected.clear();
      _future = _service.scan();
    });
  }

  Future<void> _deleteSelected(List<XcodeProject> all) async {
    final picked = all.where((p) => _selected.contains(p.path)).toList();
    if (picked.isEmpty) return;
    final total = picked.fold<int>(0, (a, p) => a + p.sizeBytes);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${picked.length} '
            '${picked.length == 1 ? "project's" : "projects'"} DerivedData?'),
        content: Text(
          "Sweep will archive each folder into Trash so it can be restored from "
          "History. The next build of each project will be a clean one.\n\n"
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

    String? restoreId;
    var totalBytes = 0;
    final logged = <CleanEventEntry>[];
    try {
      final entry = await _archive.archiveAndTrash(
        label: picked.length == 1
            ? picked.first.displayName
            : '${picked.length} Xcode projects',
        kind: 'xcode-deriveddata',
        sourcePaths: picked.map((p) => p.path).toList(),
      );
      restoreId = entry.id;
      totalBytes = entry.totalBytes;
      for (final item in entry.items) {
        logged.add(CleanEventEntry(
          path: item.originalPath,
          name: 'DerivedData · ${_basename(item.originalPath)}',
          sizeBytes: item.sizeBytes,
          disposition: 'archived_in_trash',
        ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      return;
    }
    if (logged.isNotEmpty) {
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'xcode_deriveddata',
        totalBytes: totalBytes,
        entries: logged,
        restoreId: restoreId,
      ));
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(
        'Reclaimed ${formatBytes(totalBytes)} — restorable from History',
      ),
    ));
    _refresh();
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
          _Header(
            onRefresh: _refresh,
            selectedCount: _selected.length,
            onDelete: _selected.isEmpty
                ? null
                : () async {
                    final list = await _future ?? const <XcodeProject>[];
                    if (!mounted) return;
                    await _deleteSelected(list);
                  },
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Expanded(
            child: FutureBuilder<List<XcodeProject>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.hammer_fill,
                            size: 36, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text('No DerivedData folders',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Xcode hasn\'t cached any per-project builds yet.',
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
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AuroraTokens.sp1),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final selected = _selected.contains(p.path);
                    return _ProjectRow(
                      project: p,
                      selected: selected,
                      onToggle: () {
                        setState(() {
                          if (selected) {
                            _selected.remove(p.path);
                          } else {
                            _selected.add(p.path);
                          }
                        });
                      },
                    );
                  },
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
  final VoidCallback onRefresh;
  final int selectedCount;
  final VoidCallback? onDelete;
  const _Header({
    required this.onRefresh,
    required this.selectedCount,
    required this.onDelete,
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
                'XCODE PROJECTS',
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
                'DerivedData, project by project',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each row is one project\'s incremental build cache. '
                "Trashing one only forces that project's next build to "
                'start clean.',
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
          onPressed: onRefresh,
          icon: const Icon(CupertinoIcons.refresh, size: 14),
          label: const Text('Rescan'),
        ),
        const SizedBox(width: AuroraTokens.sp2),
        FilledButton.icon(
          onPressed: onDelete,
          icon: const Icon(CupertinoIcons.trash, size: 14),
          label: Text(
            selectedCount == 0
                ? 'Trash selected'
                : 'Trash $selectedCount selected',
          ),
        ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final XcodeProject project;
  final bool selected;
  final VoidCallback onToggle;
  const _ProjectRow({
    required this.project,
    required this.selected,
    required this.onToggle,
  });

  static String _humanWhen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 30) return '${diff.inDays} d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} mo ago';
    return '${(diff.inDays / 365).round()} y ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = DateTime.now().difference(project.lastModified).inDays > 60;
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
                      project.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.folderName,
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
                    formatBytes(project.sizeBytes),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _humanWhen(project.lastModified),
                    style: TextStyle(
                      fontSize: 11,
                      color: stale ? scheme.tertiary : scheme.onSurfaceVariant,
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
