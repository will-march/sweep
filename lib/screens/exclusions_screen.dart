import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/exclusion_service.dart';
import '../theme/tokens.dart';

class ExclusionsScreen extends StatefulWidget {
  const ExclusionsScreen({super.key});

  @override
  State<ExclusionsScreen> createState() => _ExclusionsScreenState();
}

class _ExclusionsScreenState extends State<ExclusionsScreen> {
  final _service = ExclusionService();
  final _controller = TextEditingController();
  Future<List<String>>? _list;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _list = _service.readAll();
    });
  }

  Future<void> _add() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    if (!path.startsWith('/') && !path.startsWith('~/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Path must start with '/' or '~/'. Use Browse to pick a folder.",
          ),
        ),
      );
      return;
    }
    final expanded = _expand(path);
    await _service.add(expanded);
    _controller.clear();
    _refresh();
  }

  Future<void> _remove(String path) async {
    await _service.remove(path);
    _refresh();
  }

  String _expand(String input) {
    final home = Platform.environment['HOME'] ?? '';
    if (input == '~') return home;
    if (input.startsWith('~/')) return '$home${input.substring(1)}';
    return input;
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
          Text(
            'EXCLUSIONS',
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
            'Paths the cleaner will never touch',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Both the cleaner and the tree-map respect this list. '
            'Excluding a folder also excludes everything inside it.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: '~/Documents/Projects',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(CupertinoIcons.folder_fill,
                        size: 16, color: scheme.onSurfaceVariant),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'SF Mono',
                    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AuroraTokens.sp2),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(CupertinoIcons.add, size: 14),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: AuroraTokens.sp4),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _list,
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
                        Icon(CupertinoIcons.shield,
                            size: 32, color: scheme.onSurfaceVariant),
                        const SizedBox(height: AuroraTokens.sp3),
                        Text('No exclusions',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Add a path above to keep it off-limits.',
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
                    final path = items[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius:
                            BorderRadius.circular(AuroraTokens.shapeSm),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AuroraTokens.sp3,
                          vertical: AuroraTokens.sp2),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.folder_fill,
                              size: 13, color: scheme.primary),
                          const SizedBox(width: AuroraTokens.sp2),
                          Expanded(
                            child: Text(
                              path,
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
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => _remove(path),
                            icon: const Icon(CupertinoIcons.minus_circle,
                                size: 16),
                          ),
                        ],
                      ),
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
