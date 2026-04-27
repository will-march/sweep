import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/clean_event.dart';
import '../models/installed_app.dart';
import '../services/archive_trash_service.dart';
import '../services/history_service.dart';
import '../services/installed_apps_service.dart';
import '../theme/tokens.dart';
import '../utils/byte_formatter.dart';

class UninstallerScreen extends StatefulWidget {
  const UninstallerScreen({super.key});

  @override
  State<UninstallerScreen> createState() => _UninstallerScreenState();
}

class _UninstallerScreenState extends State<UninstallerScreen> {
  final _service = InstalledAppsService();
  final _archive = ArchiveTrashService();
  final _history = HistoryService();
  Future<List<InstalledApp>>? _apps;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _apps = _service.scan();
    });
  }

  Future<void> _uninstall(InstalledApp app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Uninstall ${app.name}?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The .app bundle and every leftover listed below '
                'goes to Trash. You can restore from Finder until '
                'the Trash is emptied.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: AuroraTokens.sp3),
              for (final l in app.leftovers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${l.label} — ${l.path}',
                    style: const TextStyle(
                      fontFamily: 'SF Mono',
                      fontFamilyFallback: ['Menlo', 'monospace'],
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: AuroraTokens.sp3),
              Text(
                'Total to reclaim: ${formatBytes(app.totalBytes)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
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

    final sources = <String>[
      app.bundlePath,
      ...app.leftovers.map((l) => l.path),
    ].where((p) => p.isNotEmpty).toList();

    String snackMessage = 'Uninstalled ${app.name}';
    String? restoreId;
    var totalBytes = 0;
    final logged = <CleanEventEntry>[];

    try {
      // archiveAndTrash zips every source via ditto (preserving bundle
      // metadata), drops a single .zip in ~/.Trash, deletes the
      // originals, and writes a RestoreEntry. The id we get back is
      // what lets the History screen offer a one-click restore.
      final entry = await _archive.archiveAndTrash(
        label: app.name,
        kind: 'uninstall',
        sourcePaths: sources,
      );
      restoreId = entry.id;
      totalBytes = entry.totalBytes;
      // Mirror each archived item into the history-event log so the
      // History screen can show the breakdown.
      for (final item in entry.items) {
        logged.add(CleanEventEntry(
          path: item.originalPath,
          name: '${app.name} · ${_basenameOf(item.originalPath)}',
          sizeBytes: item.sizeBytes,
          disposition: 'archived_in_trash',
        ));
      }
      snackMessage = 'Uninstalled ${app.name} — restorable from History';
    } catch (e) {
      snackMessage = 'Uninstall failed: $e';
    }

    if (logged.isNotEmpty) {
      await _history.append(CleanEvent(
        timestamp: DateTime.now(),
        mode: 'uninstall',
        totalBytes: totalBytes,
        entries: logged,
        restoreId: restoreId,
      ));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackMessage),
      ),
    );
    _refresh();
  }

  String _basenameOf(String path) {
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
                      'UNINSTALLER',
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
                      'Apps + their leftovers',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag-to-Trash leaves caches, preferences, and '
                      'containers behind. iMaculate trashes the bundle '
                      'and every file matching the bundle ID.',
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
            child: FutureBuilder<List<InstalledApp>>(
              future: _apps,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Scanning /Applications…'),
                      ],
                    ),
                  );
                }
                final apps = snap.data!;
                if (apps.isEmpty) {
                  return Center(
                    child: Text(
                      'No apps found',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: apps.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AuroraTokens.sp1),
                  itemBuilder: (context, i) =>
                      _AppRow(app: apps[i], onUninstall: () => _uninstall(apps[i])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final InstalledApp app;
  final ColorScheme scheme;
  const _AppIcon({required this.app, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final iconPath = app.iconPath;
    final hasIcon = iconPath != null && File(iconPath).existsSync();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: hasIcon
            ? Colors.transparent
            : scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasIcon
          ? Image.file(
              File(iconPath),
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) =>
                  Icon(CupertinoIcons.app_fill,
                      size: 18, color: scheme.primary),
            )
          : Icon(CupertinoIcons.app_fill,
              size: 18, color: scheme.primary),
    );
  }
}

class _AppRow extends StatefulWidget {
  final InstalledApp app;
  final VoidCallback onUninstall;
  const _AppRow({required this.app, required this.onUninstall});

  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AuroraTokens.dShort2,
        decoration: BoxDecoration(
          color: _hover
              ? scheme.surfaceContainer
              : scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AuroraTokens.shapeMd),
        ),
        padding: const EdgeInsets.fromLTRB(
            AuroraTokens.sp3, AuroraTokens.sp3, AuroraTokens.sp3, AuroraTokens.sp3),
        child: Row(
          children: [
            _AppIcon(app: widget.app, scheme: scheme),
            const SizedBox(width: AuroraTokens.sp3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.app.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.app.bundleId ?? widget.app.bundlePath,
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
                  formatBytes(widget.app.totalBytes),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (widget.app.leftovers.isNotEmpty)
                  Text(
                    '+ ${widget.app.leftovers.length} leftover'
                    '${widget.app.leftovers.length == 1 ? "" : "s"} '
                    '(${formatBytes(widget.app.leftoverBytes)})',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AuroraTokens.sp3),
            OutlinedButton.icon(
              onPressed: widget.onUninstall,
              icon: const Icon(CupertinoIcons.trash, size: 14),
              label: const Text('Uninstall'),
            ),
          ],
        ),
      ),
    );
  }
}
